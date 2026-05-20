import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    
    @State private var jsonFilename: String = ""
    @State private var imageFolderName: String = ""
    @State private var baseUrlTemplate: String = ""
    @State private var enableExtraFields: Bool = false
    @State private var includeFolderInJsonPath: Bool = true
    
    // Live preview of what a URL will look like
    var previewURL: String {
        var base = baseUrlTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        if !base.hasSuffix("/") && !base.isEmpty { base += "/" }
        return base + "example_image.png"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // MARK: - Section 1: Base URL
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Image Base URL", systemImage: "link")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.semibold)
                        
                        Text("This URL is prepended to image filenames to generate live preview links in the Visualizer.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        TextField(
                            "https://01xharshu.github.io/image-prompt-api/images/",
                            text: $baseUrlTemplate
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        
                        // Live preview
                        HStack(spacing: 6) {
                            Image(systemName: "eye")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Preview:")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                            Text(previewURL)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.accentColor)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.02))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    
                    // MARK: - Section 2: File Configuration
                    VStack(alignment: .leading, spacing: 12) {
                        Label("File Configuration", systemImage: "doc.badge.gearshape")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.semibold)
                        
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                            GridRow {
                                Text("JSON Filename:")
                                    .font(.system(.body, design: .rounded))
                                    .gridCellAnchor(.trailing)
                                TextField("e.g. data.json", text: $jsonFilename)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: 220)
                            }
                            
                            GridRow {
                                Text("Image Subfolder:")
                                    .font(.system(.body, design: .rounded))
                                    .gridCellAnchor(.trailing)
                                TextField("e.g. images", text: $imageFolderName)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: 220)
                            }
                        }
                        
                        Toggle("Include subfolder in JSON path (e.g. \"images/file.png\")", isOn: $includeFolderInJsonPath)
                            .toggleStyle(.checkbox)
                            .font(.system(.body, design: .rounded))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.02))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    
                    // MARK: - Section 3: Metadata
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Entry Metadata", systemImage: "tag")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.semibold)
                        
                        Toggle("Enable Title, Author, and Tags fields on entries", isOn: $enableExtraFields)
                            .toggleStyle(.checkbox)
                            .font(.system(.body, design: .rounded))
                        
                        if enableExtraFields {
                            Text("Extra fields will appear in the entry form and be saved into your JSON file.")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.02))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
                .padding(20)
            }
            
            Divider()
            
            // Save bar
            HStack {
                // Reset to defaults
                Button("Reset to Defaults") {
                    let defaults = AppSettings.defaultSettings
                    jsonFilename = defaults.jsonFilename
                    imageFolderName = defaults.imageFolderName
                    baseUrlTemplate = defaults.baseUrlTemplate
                    enableExtraFields = defaults.enableExtraFields
                    includeFolderInJsonPath = defaults.includeFolderInJsonPath
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button("Save Preferences") {
                    let newSettings = AppSettings(
                        jsonFilename: jsonFilename,
                        imageFolderName: imageFolderName,
                        baseUrlTemplate: baseUrlTemplate,
                        enableExtraFields: enableExtraFields,
                        includeFolderInJsonPath: includeFolderInJsonPath
                    )
                    viewModel.updateSettings(newSettings)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 520, height: 480)
        .onAppear {
            self.jsonFilename = viewModel.settings.jsonFilename
            self.imageFolderName = viewModel.settings.imageFolderName
            self.baseUrlTemplate = viewModel.settings.baseUrlTemplate
            self.enableExtraFields = viewModel.settings.enableExtraFields
            self.includeFolderInJsonPath = viewModel.settings.includeFolderInJsonPath
        }
    }
}
