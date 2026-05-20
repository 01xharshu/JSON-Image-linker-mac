import Foundation
import SwiftUI
import AppKit

class AppViewModel: ObservableObject {
    @Published var workingFolderURL: URL? = nil
    @Published var entries: [ImageEntry] = []
    @Published var settings: AppSettings = AppSettings.load()
    @Published var activeToast: Toast? = nil
    @Published var searchText: String = ""
    
    init() {
        // Auto-load last folder if available
        if let path = UserDefaults.standard.string(forKey: "com.harshu.JSON-Image-Linker.lastFolder") {
            let url = URL(fileURLWithPath: path)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                self.workingFolderURL = url
                locateJsonFile()
                loadEntries()
            }
        }
    }
    
    // Select workspace folder using NSOpenPanel
    func selectFolder() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Working Folder"
        openPanel.prompt = "Select"
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK {
            if let url = openPanel.url {
                setWorkingFolder(url)
            }
        }
    }
    
    func setWorkingFolder(_ url: URL) {
        self.workingFolderURL = url
        UserDefaults.standard.set(url.path, forKey: "com.harshu.JSON-Image-Linker.lastFolder")
        ensureImageFolderExists()
        locateJsonFile()
        loadEntries()
        showToast("Loaded workspace folder", type: .success)
    }
    
    func clearFolder() {
        self.workingFolderURL = nil
        self.entries = []
        UserDefaults.standard.removeObject(forKey: "com.harshu.JSON-Image-Linker.lastFolder")
    }
    
    // Ensure the images subdirectory exists
    func ensureImageFolderExists() {
        guard let root = workingFolderURL else { return }
        let imageFolder = root.appendingPathComponent(settings.imageFolderName)
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: imageFolder.path, isDirectory: &isDir) {
            do {
                try FileManager.default.createDirectory(at: imageFolder, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating directory: \(error)")
            }
        }
    }
    
    // Locate JSON file intelligently by scanning all .json files in the directory tree
    // and validating which ones contain a valid [ImageEntry] array.
    @Published var discoveredJsonFiles: [String] = []  // Relative paths of all valid JSON candidates
    @Published var showJsonPicker: Bool = false
    
    func locateJsonFile() {
        guard let root = workingFolderURL else { return }
        
        // 1. If the current settings already point to a valid file, do nothing
        let currentPath = root.appendingPathComponent(settings.jsonFilename)
        if FileManager.default.fileExists(atPath: currentPath.path),
           isValidImageEntryJson(at: currentPath) {
            return
        }
        
        // 2. Recursively find ALL .json files and validate each one
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return }
        
        let skipDirs: Set<String> = ["node_modules", ".git", ".xcodeproj", ".xcworkspace",
                                      "DerivedData", "build", "bin", ".build", "Pods",
                                      ".swiftpm", "xcuserdata"]
        var candidates: [String] = []
        
        for case let fileURL as URL in enumerator {
            // Skip junk directories
            let lastComponent = fileURL.lastPathComponent
            if skipDirs.contains(lastComponent) {
                enumerator.skipDescendants()
                continue
            }
            
            // Only consider .json files
            guard fileURL.pathExtension.lowercased() == "json" else { continue }
            
            // Skip known non-data files (package manifests, configs, etc.)
            let name = fileURL.lastPathComponent.lowercased()
            if name == "package.json" || name == "tsconfig.json" || name == "composer.json" ||
               name == "project.json" || name == ".eslintrc.json" || name == "launch.json" ||
               name == "settings.json" || name == "contents.json" || name == "appsettings.json" {
                continue
            }
            
            // Validate: does this file decode as [ImageEntry]?
            if isValidImageEntryJson(at: fileURL) {
                let relativePath = fileURL.path.replacingOccurrences(of: root.path + "/", with: "")
                candidates.append(relativePath)
            }
        }
        
        // 3. Decide what to do with the candidates
        if candidates.isEmpty {
            // No valid JSON found — keep current settings, the user will create a new file on first save
            return
        } else if candidates.count == 1 {
            // Exactly one match — auto-select it
            applyJsonFile(candidates[0])
            showToast("Found JSON: \(candidates[0])", type: .success)
        } else {
            // Multiple matches — show picker to the user
            DispatchQueue.main.async {
                self.discoveredJsonFiles = candidates
                self.showJsonPicker = true
            }
        }
    }
    
    /// Validate whether a file at the given URL is a JSON array of ImageEntry objects.
    private func isValidImageEntryJson(at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              data.count > 2 else { return false } // must be at least "[]"
        
        // Quick sanity check: first non-whitespace character should be '['
        let trimmed = data.drop(while: { $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 })
        guard let first = trimmed.first, first == UInt8(ascii: "[") else { return false }
        
        // Try to decode
        do {
            let entries = try JSONDecoder().decode([ImageEntry].self, from: data)
            // Must have at least one entry with non-empty image and prompt
            return entries.contains { !$0.image.isEmpty && !$0.prompt.isEmpty }
        } catch {
            return false
        }
    }
    
    /// Apply a discovered JSON file path to settings
    func applyJsonFile(_ relativePath: String) {
        var newSettings = self.settings
        newSettings.jsonFilename = relativePath
        self.settings = newSettings
        self.settings.save()
        loadEntries()
    }
    
    // Save settings and reload workspace files if file pointers changed
    func updateSettings(_ newSettings: AppSettings) {
        let oldSettings = self.settings
        self.settings = newSettings
        self.settings.save()
        
        if workingFolderURL != nil {
            ensureImageFolderExists()
            if oldSettings.jsonFilename != newSettings.jsonFilename {
                loadEntries()
            }
        }
        showToast("Settings updated successfully", type: .success)
    }
    
    // Resilient JSON Loading
    func loadEntries() {
        guard let root = workingFolderURL else { return }
        let jsonFile = root.appendingPathComponent(settings.jsonFilename)
        
        if !FileManager.default.fileExists(atPath: jsonFile.path) {
            DispatchQueue.main.async {
                self.entries = []
            }
            return
        }
        
        do {
            let data = try Data(contentsOf: jsonFile)
            let decoder = JSONDecoder()
            let loadedEntries = try decoder.decode([ImageEntry].self, from: data)
            
            // Auto-deduce repository settings from the loaded data structure
            deduceSettingsFromEntries(loadedEntries, jsonFileRelativePath: settings.jsonFilename)
            
            DispatchQueue.main.async {
                self.entries = loadedEntries
            }
        } catch {
            print("Error loading entries: \(error)")
            showToast("Failed to parse JSON: \(error.localizedDescription)", type: .error)
        }
    }
    
    // Duplicate Filename Check
    func isFilenameDuplicate(filenameWithoutExtension: String, fileExtension: String, ignoringEntry: ImageEntry? = nil) -> Bool {
        let ext = fileExtension.lowercased().isEmpty ? "png" : fileExtension.lowercased()
        let filenameWithExt = "\(filenameWithoutExtension).\(ext)"
        
        let targetPath = settings.includeFolderInJsonPath
            ? "\(settings.imageFolderName)/\(filenameWithExt)"
            : filenameWithExt
        
        return entries.contains { entry in
            if let ignoringEntry = ignoringEntry, entry.image == ignoringEntry.image {
                return false
            }
            return entry.image.lowercased() == targetPath.lowercased()
        }
    }
    
    // Create/Edit Entry
    func saveEntry(
        image: NSImage?,
        filenameWithoutExtension: String,
        fileExtension: String,
        prompt: String,
        title: String?,
        author: String?,
        tags: String?,
        originalEntry: ImageEntry?
    ) -> Bool {
        guard let root = workingFolderURL else {
            showToast("No active workspace directory", type: .error)
            return false
        }
        
        let sanitizedName = filenameWithoutExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitizedName.isEmpty {
            showToast("Filename cannot be empty", type: .error)
            return false
        }
        
        let ext = fileExtension.lowercased().isEmpty ? "png" : fileExtension.lowercased()
        let filenameWithExt = "\(sanitizedName).\(ext)"
        
        // Relative path saved in JSON
        let jsonImagePath = settings.includeFolderInJsonPath
            ? "\(settings.imageFolderName)/\(filenameWithExt)"
            : filenameWithExt
        
        // Check for duplicates
        if isFilenameDuplicate(filenameWithoutExtension: sanitizedName, fileExtension: ext, ignoringEntry: originalEntry) {
            showToast("Filename '\(filenameWithExt)' already exists!", type: .error)
            return false
        }
        
        let fileManager = FileManager.default
        let imageFolder = root.appendingPathComponent(settings.imageFolderName)
        let fileDestination = imageFolder.appendingPathComponent(filenameWithExt)
        
        // 1. Save Image Binary to disk if provided
        if let image = image {
            guard let imageData = image.fileData(for: ext) else {
                showToast("Failed to convert image format", type: .error)
                return false
            }
            
            do {
                ensureImageFolderExists()
                try imageData.write(to: fileDestination)
            } catch {
                showToast("Failed to save image file: \(error.localizedDescription)", type: .error)
                return false
            }
        } else if let original = originalEntry, original.filenameOnly != sanitizedName || original.fileExtension != ext {
            // Filename changed but no new image provided: rename existing file
            let oldFilenameWithExt = "\(original.filenameOnly).\(original.fileExtension)"
            let oldFileDestination = imageFolder.appendingPathComponent(oldFilenameWithExt)
            if fileManager.fileExists(atPath: oldFileDestination.path) {
                do {
                    ensureImageFolderExists()
                    try fileManager.moveItem(at: oldFileDestination, to: fileDestination)
                } catch {
                    showToast("Failed to rename image file", type: .error)
                    return false
                }
            }
        }
        
        // 2. Parse Tags (comma-separated to String Array)
        var parsedTags: [String]? = nil
        if let tags = tags, !tags.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parsedTags = tags.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        
        // 3. Create/Update entry
        let newEntry = ImageEntry(
            image: jsonImagePath,
            prompt: prompt,
            title: title?.isEmpty == false ? title : nil,
            author: author?.isEmpty == false ? author : nil,
            tags: parsedTags
        )
        
        // 4. Update elements list
        if let original = originalEntry {
            if let index = entries.firstIndex(where: { $0.image == original.image }) {
                entries[index] = newEntry
                // Clean up old file if name/path changed
                if original.image != newEntry.image {
                    let oldFileDestination = root.appendingPathComponent(original.image)
                    // Only delete if we didn't rename it in step 1
                    if !fileManager.fileExists(atPath: fileDestination.path) || oldFileDestination != fileDestination {
                        try? fileManager.removeItem(at: oldFileDestination)
                    }
                }
            } else {
                entries.append(newEntry)
            }
        } else {
            entries.append(newEntry)
        }
        
        // 5. Automated Backup & Save JSON
        let jsonFile = root.appendingPathComponent(settings.jsonFilename)
        let backupFile = root.appendingPathComponent("\(settings.jsonFilename).backup")
        
        // Ensure the directory containing the JSON file exists!
        let jsonFolder = jsonFile.deletingLastPathComponent()
        try? fileManager.createDirectory(at: jsonFolder, withIntermediateDirectories: true, attributes: nil)
        
        if fileManager.fileExists(atPath: jsonFile.path) {
            try? fileManager.removeItem(at: backupFile)
            try? fileManager.copyItem(at: jsonFile, to: backupFile)
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let jsonData = try encoder.encode(entries)
            try jsonData.write(to: jsonFile)
            showToast(originalEntry == nil ? "Saved entry successfully" : "Updated entry successfully", type: .success)
            return true
        } catch {
            showToast("Failed to save JSON: \(error.localizedDescription)", type: .error)
            return false
        }
    }
    
    // Delete entry
    func deleteEntry(_ entry: ImageEntry) {
        guard let root = workingFolderURL else { return }
        
        let fileManager = FileManager.default
        let jsonFile = root.appendingPathComponent(settings.jsonFilename)
        let backupFile = root.appendingPathComponent("\(settings.jsonFilename).backup")
        
        // 1. Delete image
        let imageLocation = root.appendingPathComponent(entry.image)
        if fileManager.fileExists(atPath: imageLocation.path) {
            try? fileManager.removeItem(at: imageLocation)
        }
        
        // 2. Backup existing JSON
        let jsonFolder = jsonFile.deletingLastPathComponent()
        try? fileManager.createDirectory(at: jsonFolder, withIntermediateDirectories: true, attributes: nil)
        
        if fileManager.fileExists(atPath: jsonFile.path) {
            try? fileManager.removeItem(at: backupFile)
            try? fileManager.copyItem(at: jsonFile, to: backupFile)
        }
        
        // 3. Remove and Save
        entries.removeAll { $0.image == entry.image }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let jsonData = try encoder.encode(entries)
            try jsonData.write(to: jsonFile)
            showToast("Deleted entry", type: .info)
        } catch {
            showToast("Failed to update JSON after deletion: \(error.localizedDescription)", type: .error)
        }
    }
    
    func showToast(_ message: String, type: Toast.ToastType) {
        DispatchQueue.main.async {
            self.activeToast = Toast(message: message, type: type)
        }
    }
    
    // Check if the image file already exists physically on the disk
    func fileExistsOnDisk(filenameWithoutExtension: String, fileExtension: String) -> Bool {
        guard let root = workingFolderURL else { return false }
        let ext = fileExtension.lowercased().isEmpty ? "png" : fileExtension.lowercased()
        let filenameWithExt = "\(filenameWithoutExtension).\(ext)"
        let fileDestination = root.appendingPathComponent(settings.imageFolderName).appendingPathComponent(filenameWithExt)
        return FileManager.default.fileExists(atPath: fileDestination.path)
    }
    
    // Auto-deduce settings from loaded entries
    private func deduceSettingsFromEntries(_ loadedEntries: [ImageEntry], jsonFileRelativePath: String) {
        guard let firstEntry = loadedEntries.first else { return }
        
        let path = firstEntry.image
        // Get the directory of the JSON relative to the root
        let jsonFolder = URL(fileURLWithPath: jsonFileRelativePath).deletingLastPathComponent().relativePath
        
        var deducedIncludeFolder = settings.includeFolderInJsonPath
        var deducedImageFolderName = settings.imageFolderName
        
        if path.contains("/") {
            deducedIncludeFolder = true
            let url = URL(fileURLWithPath: path)
            let folderPrefix = url.deletingLastPathComponent().relativePath
            
            if let root = workingFolderURL {
                let pathRelToJson = root.appendingPathComponent(jsonFolder).appendingPathComponent(folderPrefix)
                let pathRelToRoot = root.appendingPathComponent(folderPrefix)
                
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: pathRelToJson.path, isDirectory: &isDir), isDir.boolValue {
                    // It is relative to the JSON!
                    let resolvedRelativeFolder = jsonFolder == "." || jsonFolder.isEmpty
                        ? folderPrefix
                        : "\(jsonFolder)/\(folderPrefix)"
                    deducedImageFolderName = resolvedRelativeFolder
                } else if FileManager.default.fileExists(atPath: pathRelToRoot.path, isDirectory: &isDir), isDir.boolValue {
                    // It is relative to the root!
                    deducedImageFolderName = folderPrefix
                }
            }
        } else {
            // No slashes, meaning folder is not included in the JSON path
            deducedIncludeFolder = false
            
            // Locate where the images are by finding the first image file in the project
            if let root = workingFolderURL {
                let imageName = URL(fileURLWithPath: path).lastPathComponent
                if let foundImageURL = findFileRecursively(name: imageName, under: root) {
                    let relativeFolder = foundImageURL.deletingLastPathComponent().path
                        .replacingOccurrences(of: root.path + "/", with: "")
                        .replacingOccurrences(of: root.path, with: "")
                    deducedImageFolderName = relativeFolder.isEmpty ? "images" : relativeFolder
                }
            }
        }
        
        // Update setting state if deduced values differ
        if deducedIncludeFolder != settings.includeFolderInJsonPath || deducedImageFolderName != settings.imageFolderName {
            var newSettings = self.settings
            newSettings.includeFolderInJsonPath = deducedIncludeFolder
            newSettings.imageFolderName = deducedImageFolderName
            
            DispatchQueue.main.async {
                self.settings = newSettings
                self.settings.save()
            }
            print("Deduced settings: imageFolderName = \(deducedImageFolderName), includeFolderInJsonPath = \(deducedIncludeFolder)")
        }
    }
    
    private func findFileRecursively(name: String, under dir: URL) -> URL? {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = fileManager.enumerator(
            at: dir,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return nil }
        
        for case let fileURL as URL in enumerator {
            let pathComponents = fileURL.pathComponents
            if pathComponents.contains("node_modules") ||
               pathComponents.contains(".git") ||
               pathComponents.contains(".xcodeproj") ||
               pathComponents.contains("DerivedData") ||
               pathComponents.contains("build") ||
               pathComponents.contains("bin") {
                enumerator.skipDescendants()
                continue
            }
            if fileURL.lastPathComponent == name {
                return fileURL
            }
        }
        return nil
    }
}
