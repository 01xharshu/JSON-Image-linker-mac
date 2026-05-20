import SwiftUI

struct VisualizerView: View {
    @ObservedObject var viewModel: AppViewModel
    
    @State private var isGridView = true
    @State private var searchText = ""
    @State private var refreshID = UUID()
    @State private var showLocalImages = true // Local images by default
    
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
            // Control Bar
            HStack(spacing: 12) {
                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    TextField("Search gallery...", text: $searchText)
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
                .frame(maxWidth: 300)
                
                Spacer()
                
                // Source toggle: Local vs Remote
                Picker("Source", selection: $showLocalImages) {
                    Text("Local").tag(true)
                    Text("Remote").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 130)
                .help("Toggle between local disk images and remote GitHub URLs")
                
                // Refresh
                Button(action: {
                    refreshID = UUID()
                    viewModel.loadEntries()
                    viewModel.showToast("Refreshed gallery", type: .info)
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Refresh images")
                
                // Layout Toggle
                Picker("Layout", selection: $isGridView) {
                    Image(systemName: "square.grid.2x2.fill").tag(true)
                    Image(systemName: "list.bullet").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            Divider()
            
            // Content
            if filteredEntries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    if isGridView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 16)], spacing: 16) {
                            ForEach(filteredEntries) { entry in
                                VisualizerCard(
                                    entry: entry,
                                    settings: viewModel.settings,
                                    rootURL: viewModel.workingFolderURL,
                                    isGrid: true,
                                    showLocal: showLocalImages
                                )
                                .id("\(entry.image)-\(refreshID)-\(showLocalImages)")
                            }
                        }
                        .padding(20)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredEntries) { entry in
                                VisualizerCard(
                                    entry: entry,
                                    settings: viewModel.settings,
                                    rootURL: viewModel.workingFolderURL,
                                    isGrid: false,
                                    showLocal: showLocalImages
                                )
                                .id("\(entry.image)-\(refreshID)-\(showLocalImages)")
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .background(Color(NSColor.underPageBackgroundColor))
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                Image(systemName: "photo.stack")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            Text("No Entries to Visualize")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Text("Add entries from the Editor tab or adjust your search.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Visualizer Card
struct VisualizerCard: View {
    let entry: ImageEntry
    let settings: AppSettings
    let rootURL: URL?
    let isGrid: Bool
    let showLocal: Bool
    
    @State private var isHovering = false
    @State private var copied = false
    @State private var localImage: NSImage? = nil
    
    // Compute the remote URL
    var liveURL: URL? {
        let trimmedBase = settings.baseUrlTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBase.isEmpty else { return nil }
        
        var baseString = trimmedBase
        if !baseString.hasSuffix("/") { baseString += "/" }
        
        var relativePath = entry.image
        
        // Smart deduplication: avoid "images/images/file.png"
        if let imageFolderName = relativePath.components(separatedBy: "/").first {
            let folderWithSlash = imageFolderName + "/"
            if relativePath.hasPrefix(folderWithSlash) {
                let baseWithoutSlash = String(baseString.dropLast())
                if baseWithoutSlash.hasSuffix(folderWithSlash.dropLast()) {
                    relativePath = String(relativePath.dropFirst(folderWithSlash.count))
                }
            }
        }
        
        return URL(string: baseString + relativePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)
    }
    
    var body: some View {
        Group {
            if isGrid {
                gridCard
            } else {
                listRow
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .onHover { hover in isHovering = hover }
        .onAppear { loadLocalImage() }
        .onChange(of: entry) { _ in loadLocalImage() }
    }
    
    // MARK: - Grid Card
    private var gridCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            imageContainer
                .frame(height: 160)
                .clipped()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(entry.filenameOnly)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(".\(entry.fileExtension)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(Capsule())
                }
                
                Text(entry.prompt)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .frame(minHeight: 44, alignment: .topLeading)
                
                extraFieldsContainer
                
                Spacer(minLength: 0)
                
                actionButtons
            }
            .padding(14)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isHovering ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.06),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(isHovering ? 0.12 : 0.04), radius: isHovering ? 8 : 3, x: 0, y: isHovering ? 4 : 1)
        .scaleEffect(isHovering ? 1.01 : 1.0)
    }
    
    // MARK: - List Row
    private var listRow: some View {
        HStack(spacing: 14) {
            imageContainer
                .frame(width: 130, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.filenameOnly)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                    
                    Text(".\(entry.fileExtension)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(Capsule())
                    
                    Spacer()
                    actionButtons
                }
                
                Text(entry.prompt)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                extraFieldsContainer
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isHovering ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.06),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(isHovering ? 0.08 : 0.03), radius: isHovering ? 6 : 2, x: 0, y: isHovering ? 3 : 1)
        .scaleEffect(isHovering ? 1.005 : 1.0)
    }
    
    // MARK: - Image Container (Local or Remote)
    private var imageContainer: some View {
        ZStack {
            Color.secondary.opacity(0.04)
            
            if showLocal {
                // Show local image from disk
                if let img = localImage {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity.animation(.easeIn(duration: 0.2)))
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("Not on Disk")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.4))
                    }
                }
            } else {
                // Show remote image via AsyncImage
                if let url = liveURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .scaleEffect(0.7)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .transition(.opacity.animation(.easeIn(duration: 0.2)))
                        case .failure:
                            VStack(spacing: 4) {
                                Image(systemName: "exclamationmark.icloud")
                                    .font(.title2)
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text("Fetch Error")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                            .help("Unable to load: \(url.absoluteString)")
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "link.badge.plus")
                            .font(.title2)
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("No URL Template")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.4))
                    }
                }
            }
        }
    }
    
    // MARK: - Extra Fields
    private var extraFieldsContainer: some View {
        Group {
            if settings.enableExtraFields && (entry.title != nil || entry.author != nil || entry.tags != nil) {
                VStack(alignment: .leading, spacing: 4) {
                    if let title = entry.title {
                        Label(title, systemImage: "textformat")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.primary.opacity(0.7))
                            .lineLimit(1)
                    }
                    if let author = entry.author {
                        Label(author, systemImage: "person")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.primary.opacity(0.7))
                            .lineLimit(1)
                    }
                    if let tagsList = entry.tags, !tagsList.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(tagsList, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundColor(.accentColor)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Color.accentColor.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 8) {
            if let url = liveURL {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { copied = false }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                        Text(copied ? "Copied" : "URL")
                            .font(.system(.caption2, design: .rounded))
                            .fontWeight(.medium)
                    }
                    .foregroundColor(copied ? .green : .accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(copied ? Color.green.opacity(0.1) : Color.accentColor.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(url.absoluteString)
            }
        }
    }
    
    // MARK: - Load Local Image
    private func loadLocalImage() {
        guard let root = rootURL else { return }
        
        // Try multiple resolution strategies
        let candidates = buildImageCandidates(root: root)
        
        DispatchQueue.global(qos: .userInitiated).async {
            for candidateURL in candidates {
                if let image = NSImage(contentsOf: candidateURL) {
                    // Downsample for memory efficiency
                    let maxDim: CGFloat = 400
                    let ratio = min(maxDim / image.size.width, maxDim / image.size.height, 1.0)
                    let targetSize = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
                    let thumb = NSImage(size: targetSize)
                    thumb.lockFocus()
                    image.draw(in: NSRect(origin: .zero, size: targetSize),
                               from: NSRect(origin: .zero, size: image.size),
                               operation: .copy, fraction: 1.0)
                    thumb.unlockFocus()
                    DispatchQueue.main.async {
                        self.localImage = thumb
                    }
                    return
                }
            }
            DispatchQueue.main.async {
                self.localImage = nil
            }
        }
    }
    
    /// Build a prioritized list of candidate file URLs to try loading
    private func buildImageCandidates(root: URL) -> [URL] {
        var candidates: [URL] = []
        
        let imagePath = entry.image
        let jsonDir = URL(fileURLWithPath: settings.jsonFilename).deletingLastPathComponent().relativePath
        
        // 1. Direct: root/imagePath
        candidates.append(root.appendingPathComponent(imagePath))
        
        // 2. Relative to JSON file location: root/jsonDir/imagePath
        if !jsonDir.isEmpty && jsonDir != "." {
            candidates.append(root.appendingPathComponent(jsonDir).appendingPathComponent(imagePath))
        }
        
        // 3. Inside the image folder: root/imageFolderName/filename
        let filename = URL(fileURLWithPath: imagePath).lastPathComponent
        candidates.append(root.appendingPathComponent(settings.imageFolderName).appendingPathComponent(filename))
        
        // 4. Directly in root with just the filename
        candidates.append(root.appendingPathComponent(filename))
        
        return candidates
    }
}
