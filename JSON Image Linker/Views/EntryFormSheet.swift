import SwiftUI
import UniformTypeIdentifiers

struct EntryFormSheet: View {
    @ObservedObject var viewModel: AppViewModel
    var originalEntry: ImageEntry? // nil if creating a new one
    var onDismiss: () -> Void
    
    @State private var image: NSImage? = nil
    @State private var filename: String = ""
    @State private var fileExtension: String = "png"
    @State private var prompt: String = ""
    
    // Optional extra fields
    @State private var title: String = ""
    @State private var author: String = ""
    @State private var tags: String = ""
    
    @State private var isDragOver = false
    @State private var hasClipboardImage = false
    
    var isDuplicate: Bool {
        guard !filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return viewModel.isFilenameDuplicate(filenameWithoutExtension: filename, fileExtension: fileExtension, ignoringEntry: originalEntry)
    }
    
    var isOverwritingDiskFile: Bool {
        guard !filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if let original = originalEntry, filename.lowercased() == original.filenameOnly.lowercased() && fileExtension.lowercased() == original.fileExtension.lowercased() {
            return false
        }
        return viewModel.fileExistsOnDisk(filenameWithoutExtension: filename, fileExtension: fileExtension)
    }
    
    var canSave: Bool {
        // Must have an image (either new or existing) and filename and prompt
        let hasImage = image != nil || originalEntry != nil
        let hasName = !filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPrompt = !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasImage && hasName && hasPrompt && !isDuplicate
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(originalEntry == nil ? "Add New Entry" : "Edit Entry")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            Divider()
            
            // Scrollable Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Image Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Image Asset")
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 8) {
                            if let image = image {
                                ZStack(alignment: .topTrailing) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 180)
                                        .cornerRadius(8)
                                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                                        .padding(.vertical, 8)
                                    
                                    Button(action: { self.image = nil }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.red)
                                            .background(Circle().fill(Color.white))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(4)
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 36))
                                        .foregroundColor(isDragOver ? .accentColor : .secondary)
                                    
                                    Text("Drag & drop image, paste from clipboard, or click to browse")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                    
                                    HStack(spacing: 12) {
                                        Button(action: selectImageFile) {
                                            Label("Browse File", systemImage: "doc.badge.plus")
                                        }
                                        
                                        if hasClipboardImage {
                                            Button(action: pasteFromClipboard) {
                                                Label("Paste Clipboard", systemImage: "doc.on.clipboard")
                                            }
                                            .foregroundColor(.accentColor)
                                        }
                                    }
                                }
                                .frame(height: 180)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isDragOver ? Color.accentColor : Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6]))
                                        .background(isDragOver ? Color.accentColor.opacity(0.05) : Color.black.opacity(0.01))
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectImageFile()
                                }
                            }
                        }
                        .onDrop(of: [.fileURL, .image], isTargeted: $isDragOver) { providers in
                            return handleImageDrop(providers: providers)
                        }
                    }
                    
                    // Filename Section
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Filename")
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 8) {
                            TextField("e.g. sunset_landscape", text: $filename)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            
                            Text(".\(fileExtension)")
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        if isDuplicate {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Filename already exists in JSON! Duplicates are not allowed.")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.orange)
                            }
                            .padding(.top, 2)
                        } else if isOverwritingDiskFile {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.yellow)
                                Text("File already exists on disk. Saving will overwrite the image asset.")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.yellow)
                            }
                            .padding(.top, 2)
                        }
                    }
                    
                    // Prompt Section
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prompt")
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                        
                        TextEditor(text: $prompt)
                            .frame(minHeight: 100)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                            .font(.system(.body, design: .rounded))
                    }
                    
                    // Extra Fields (Visible only if enabled in Settings)
                    if viewModel.settings.enableExtraFields {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Additional Meta Fields")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 10) {
                                HStack {
                                    Text("Title")
                                        .frame(width: 60, alignment: .leading)
                                    TextField("Optional Title", text: $title)
                                        .textFieldStyle(.roundedBorder)
                                }
                                
                                HStack {
                                    Text("Author")
                                        .frame(width: 60, alignment: .leading)
                                    TextField("Optional Author", text: $author)
                                        .textFieldStyle(.roundedBorder)
                                }
                                
                                HStack {
                                    Text("Tags")
                                        .frame(width: 60, alignment: .leading)
                                    TextField("Comma separated (e.g. nature, outdoors)", text: $tags)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                            .padding(12)
                            .background(Color.secondary.opacity(0.04))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(24)
            }
            
            Divider()
            
            // Bottom Action Bar
            HStack {
                Spacer()
                
                Button("Cancel", action: onDismiss)
                    .keyboardShortcut(.cancelAction)
                
                Button(action: saveEntry) {
                    Text(originalEntry == nil ? "Save Entry" : "Update Entry")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 500, height: 620)
        .onAppear {
            if let entry = originalEntry, let root = viewModel.workingFolderURL {
                let fileURL = root.appendingPathComponent(entry.image)
                if let loadedImage = NSImage(contentsOf: fileURL) {
                    self.image = loadedImage
                }
                self.filename = entry.filenameOnly
                self.fileExtension = entry.fileExtension
                self.prompt = entry.prompt
                
                self.title = entry.title ?? ""
                self.author = entry.author ?? ""
                self.tags = entry.tags?.joined(separator: ", ") ?? ""
            } else {
                // New entry — suggest the next filename based on the last entry's pattern
                let suggestion = viewModel.suggestNextFilename()
                self.filename = suggestion.name
                self.fileExtension = suggestion.ext
            }
            checkClipboard()
        }
    }
    
    // Check clipboard for available image data
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        hasClipboardImage = pasteboard.canReadObject(forClasses: [NSImage.self], options: nil)
    }
    
    // Paste image from clipboard
    private func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        if let pastedImage = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            self.image = pastedImage
            
            // If the user copied a file from Finder, extract filename and extension
            if let fileURLString = pasteboard.string(forType: .fileURL), let url = URL(string: fileURLString) {
                self.filename = url.deletingPathExtension().lastPathComponent
                self.fileExtension = url.pathExtension.isEmpty ? "png" : url.pathExtension
            } else {
                if self.filename.isEmpty {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyyMMdd_HHmmss"
                    let dateString = formatter.string(from: Date())
                    self.filename = "pasted_image_\(dateString)"
                    self.fileExtension = "png"
                }
            }
            viewModel.showToast("Pasted image from clipboard", type: .success)
        }
        checkClipboard()
    }
    
    // File open picker
    private func selectImageFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Image File"
        openPanel.allowedContentTypes = [.image]
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK {
            if let url = openPanel.url, let nsImage = NSImage(contentsOf: url) {
                self.image = nsImage
                self.filename = url.deletingPathExtension().lastPathComponent
                self.fileExtension = url.pathExtension.isEmpty ? "png" : url.pathExtension
            }
        }
    }
    
    // Handle drop input providers
    private func handleImageDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        // 1. Check for file path
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                
                if let nsImage = NSImage(contentsOf: url) {
                    DispatchQueue.main.async {
                        self.image = nsImage
                        self.filename = url.deletingPathExtension().lastPathComponent
                        self.fileExtension = url.pathExtension.isEmpty ? "png" : url.pathExtension
                    }
                }
            }
            return true
        }
        
        // 2. Check for raw image data
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let data = data, let nsImage = NSImage(data: data) {
                    DispatchQueue.main.async {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyyMMdd_HHmmss"
                        let dateString = formatter.string(from: Date())
                        self.image = nsImage
                        self.filename = "dropped_image_\(dateString)"
                        self.fileExtension = "png"
                    }
                }
            }
            return true
        }
        
        return false
    }
    
    // Save operation
    private func saveEntry() {
        // We only pass `image` if the image actually changed. 
        // If editing and image wasn't replaced, we pass nil so the ViewModel keeps the current image.
        let success = viewModel.saveEntry(
            image: image,
            filenameWithoutExtension: filename,
            fileExtension: fileExtension,
            prompt: prompt,
            title: title,
            author: author,
            tags: tags,
            originalEntry: originalEntry
        )
        if success {
            onDismiss()
        }
    }
}
