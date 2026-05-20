import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var selectedEntry: ImageEntry?
    @Binding var showFormSheet: Bool
    
    @State private var searchText = ""
    
    var filteredEntries: [ImageEntry] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.entries
        } else {
            return viewModel.entries.filter { entry in
                entry.filenameOnly.localizedCaseInsensitiveContains(searchText) ||
                entry.prompt.localizedCaseInsensitiveContains(searchText) ||
                (entry.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (entry.author?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                TextField("Search entries...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .rounded))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            // Entry count badge
            if !filteredEntries.isEmpty {
                HStack {
                    Text("\(filteredEntries.count) entries")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                    if !searchText.isEmpty {
                        Text("(filtered)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
            
            Divider()
            
            // Entries List
            if filteredEntries.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 56, height: 56)
                        Image(systemName: searchText.isEmpty ? "photo.stack" : "magnifyingglass")
                            .font(.system(size: 22))
                            .foregroundColor(.secondary.opacity(0.4))
                    }
                    Text(searchText.isEmpty ? "No entries yet" : "No matches found")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(filteredEntries) { entry in
                    SidebarRow(entry: entry, rootURL: viewModel.workingFolderURL)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedEntry = entry
                            showFormSheet = true
                        }
                        .contextMenu {
                            Button {
                                selectedEntry = entry
                                showFormSheet = true
                            } label: {
                                Label("Edit Entry", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                viewModel.deleteEntry(entry)
                            } label: {
                                Label("Delete Entry", systemImage: "trash")
                            }
                        }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 250, maxWidth: 320)
    }
}

struct SidebarRow: View {
    let entry: ImageEntry
    let rootURL: URL?
    @State private var thumbnail: NSImage? = nil
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                } else {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.subheadline)
                                .foregroundColor(.secondary.opacity(0.5))
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            
            // Text info
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(entry.filenameOnly)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(".\(entry.fileExtension)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                Text(entry.prompt)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.secondary.opacity(0.04) : Color.clear)
        )
        .onHover { hover in isHovering = hover }
        .onAppear { loadImage() }
        .onChange(of: entry) { _ in loadImage() }
    }
    
    private func loadImage() {
        guard let root = rootURL else { return }
        
        // Try multiple paths to find the image
        let imagePath = entry.image
        let filename = URL(fileURLWithPath: imagePath).lastPathComponent
        let candidates = [
            root.appendingPathComponent(imagePath),
            root.appendingPathComponent("images").appendingPathComponent(filename),
            root.appendingPathComponent(filename)
        ]
        
        DispatchQueue.global(qos: .userInitiated).async {
            for candidateURL in candidates {
                if let image = NSImage(contentsOf: candidateURL) {
                    let size = NSSize(width: 88, height: 88)
                    let thumbnailImage = NSImage(size: size)
                    thumbnailImage.lockFocus()
                    image.draw(in: NSRect(origin: .zero, size: size),
                               from: NSRect(origin: .zero, size: image.size),
                               operation: .copy, fraction: 1.0)
                    thumbnailImage.unlockFocus()
                    DispatchQueue.main.async {
                        self.thumbnail = thumbnailImage
                    }
                    return
                }
            }
            DispatchQueue.main.async {
                self.thumbnail = nil
            }
        }
    }
}
