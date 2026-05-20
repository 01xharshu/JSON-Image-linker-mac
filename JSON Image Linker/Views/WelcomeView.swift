import SwiftUI

struct WelcomeView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isHovering = false
    @State private var pulse = false
    @State private var isDragOver = false
    
    var body: some View {
        ZStack {
            // Layered ambient background
            backgroundLayer
            
            VStack(spacing: 28) {
                Spacer()
                
                // App icon with pulse ring
                ZStack {
                    // Outer pulse ring
                    Circle()
                        .stroke(Color.accentColor.opacity(pulse ? 0.0 : 0.25), lineWidth: 2)
                        .frame(width: 130, height: 130)
                        .scaleEffect(pulse ? 1.3 : 1.0)
                        .animation(.easeOut(duration: 2.0).repeatForever(autoreverses: false), value: pulse)
                    
                    // Glass circle
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 110, height: 110)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .accentColor.opacity(0.2), radius: 20, x: 0, y: 10)
                    
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(isHovering ? 1.05 : 1.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isHovering)
                
                // App title
                VStack(spacing: 10) {
                    Text("JSON Image Linker")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Link prompts to images and compile JSON databases natively.")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Primary action button with glass effect
                Button(action: { viewModel.selectFolder() }) {
                    HStack(spacing: 10) {
                        Image(systemName: "folder.fill")
                            .font(.headline)
                        Text("Select Working Folder")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .accentColor.opacity(0.2), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .scaleEffect(isHovering ? 1.04 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isHovering)
                .onHover { hover in isHovering = hover }
                
                // Drag & drop hint
                Text("or drag a folder here")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.7))
                
                Spacer()
                
                // Footer
                HStack(spacing: 4) {
                    Image(systemName: "apple.logo")
                        .font(.caption2)
                    Text("Designed for macOS Sonoma and later")
                }
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.secondary.opacity(0.5))
                .padding(.bottom, 20)
            }
            
            // Drag overlay
            if isDragOver {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .background(Color.accentColor.opacity(0.06))
                    .padding(20)
                    .transition(.opacity)
            }
        }
        .frame(minWidth: 600, minHeight: 450)
        .onAppear { pulse = true }
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            handleFolderDrop(providers: providers)
        }
    }
    
    private var backgroundLayer: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
            
            // Top-left accent glow
            RadialGradient(
                colors: [Color.accentColor.opacity(0.07), Color.clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 350
            )
            
            // Bottom-right purple glow
            RadialGradient(
                colors: [Color.purple.opacity(0.05), Color.clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 350
            )
        }
    }
    
    private func handleFolderDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                DispatchQueue.main.async {
                    viewModel.setWorkingFolder(url)
                }
            }
        }
        return true
    }
}
