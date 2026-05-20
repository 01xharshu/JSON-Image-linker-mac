import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: AppViewModel
    
    @State private var selectedTab = 0
    @State private var selectedEntryToEdit: ImageEntry? = nil
    @State private var showFormSheet = false
    @State private var isAddHovered = false
    
    var body: some View {
        Group {
            if viewModel.workingFolderURL == nil {
                WelcomeView(viewModel: viewModel)
            } else {
                NavigationSplitView {
                    SidebarView(viewModel: viewModel, selectedEntry: $selectedEntryToEdit, showFormSheet: $showFormSheet)
                        .toolbar {
                            ToolbarItem {
                                Button(action: {
                                    selectedEntryToEdit = nil
                                    showFormSheet = true
                                }) {
                                    Label("Add Entry", systemImage: "plus")
                                }
                                .help("Add New Entry")
                            }
                            ToolbarItem {
                                SettingsLink {
                                    Label("Settings", systemImage: "gearshape")
                                }
                                .help("Open Settings (⌘ ,)")
                            }
                        }
                } detail: {
                    TabView(selection: $selectedTab) {
                        editorTabPane
                            .tabItem {
                                Label("Editor", systemImage: "pencil.line")
                            }
                            .tag(0)
                        
                        VisualizerView(viewModel: viewModel)
                            .tabItem {
                                Label("Visualizer", systemImage: "photo.stack")
                            }
                            .tag(1)
                    }
                    .padding(8)
                }
            }
        }
        .sheet(isPresented: $showFormSheet, onDismiss: { selectedEntryToEdit = nil }) {
            EntryFormSheet(viewModel: viewModel, originalEntry: selectedEntryToEdit) {
                showFormSheet = false
            }
        }
        .sheet(isPresented: $viewModel.showJsonPicker) {
            JsonPickerSheet(viewModel: viewModel)
        }
        .overlay(alignment: .bottom) {
            if let toast = viewModel.activeToast {
                ToastView(toast: toast) {
                    viewModel.activeToast = nil
                }
                .padding(.bottom, 16)
            }
        }
    }
    
    // MARK: - Editor Pane
    private var editorTabPane: some View {
        ZStack {
            // Subtle background
            Color(NSColor.windowBackgroundColor)
            
            VStack(spacing: 28) {
                Spacer()
                
                // Central icon with glass circle
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .white.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .accentColor.opacity(0.15), radius: 16, x: 0, y: 8)
                    
                    Image(systemName: "folder.fill.badge.gearshape")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 12) {
                    Text("Active Workspace")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                    
                    if let folder = viewModel.workingFolderURL {
                        Text(folder.lastPathComponent)
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.primary.opacity(0.8))
                        
                        Text(folder.path)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 40)
                        
                        // Active JSON file badge
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.fill")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                            Text(viewModel.settings.jsonFilename)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                
                // Primary action button
                Button(action: {
                    selectedEntryToEdit = nil
                    showFormSheet = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text("Add New Entry")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .scaleEffect(isAddHovered ? 1.03 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAddHovered)
                .onHover { hover in isAddHovered = hover }
                
                // Stats row with glass cards
                HStack(spacing: 20) {
                    StatCard(label: "JSON Entries", value: "\(viewModel.entries.count)", icon: "doc.text")
                    StatCard(label: "Image Files", value: "\(countImageFiles())", icon: "photo")
                    StatCard(label: "JSON File", value: URL(fileURLWithPath: viewModel.settings.jsonFilename).lastPathComponent, icon: "doc.badge.gearshape")
                }
                .padding(.top, 12)
                
                Spacer()
                
                // Disconnect link
                Button(action: { viewModel.clearFolder() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "folder.badge.minus")
                        Text("Disconnect Workspace")
                    }
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func countImageFiles() -> Int {
        guard let root = viewModel.workingFolderURL else { return 0 }
        let imageFolder = root.appendingPathComponent(viewModel.settings.imageFolderName)
        let contents = try? FileManager.default.contentsOfDirectory(atPath: imageFolder.path)
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp"]
        return contents?.filter { file in
            imageExtensions.contains(URL(fileURLWithPath: file).pathExtension.lowercased())
        }.count ?? 0
    }
}

// MARK: - Stat Card (Glass)
struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor.opacity(0.8))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .lineLimit(1)
                Text(label)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - JSON File Picker Sheet
struct JsonPickerSheet: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                        Text("Multiple JSON Files Found")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                    }
                    Text("Select the file containing your image-prompt data.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.discoveredJsonFiles.indices, id: \.self) { index in
                        let path = viewModel.discoveredJsonFiles[index]
                        Button(action: { selectedIndex = index }) {
                            HStack(spacing: 12) {
                                Image(systemName: selectedIndex == index ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundColor(selectedIndex == index ? .accentColor : .secondary.opacity(0.5))
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(URL(fileURLWithPath: path).lastPathComponent)
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.medium)
                                    Text(path)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if let root = viewModel.workingFolderURL {
                                    let fileURL = root.appendingPathComponent(path)
                                    let count = countEntries(at: fileURL)
                                    Text("\(count) entries")
                                        .font(.system(.caption, design: .rounded))
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedIndex == index ? Color.accentColor.opacity(0.08) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedIndex == index ? Color.accentColor.opacity(0.25) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Button(action: {
                    guard selectedIndex < viewModel.discoveredJsonFiles.count else { return }
                    let chosen = viewModel.discoveredJsonFiles[selectedIndex]
                    viewModel.applyJsonFile(chosen)
                    viewModel.showToast("Using: \(chosen)", type: .success)
                    dismiss()
                }) {
                    Text("Use Selected File")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 520, height: 420)
    }
    
    private func countEntries(at url: URL) -> Int {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([ImageEntry].self, from: data) else { return 0 }
        return entries.count
    }
}
