import SwiftUI

struct Toast: Equatable, Identifiable {
    let id = UUID()
    enum ToastType {
        case success
        case error
        case warning
        case info
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
    }
    
    var message: String
    var type: ToastType
    var duration: Double = 3.0
}

struct ToastView: View {
    let toast: Toast
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.icon)
                .font(.title3)
                .foregroundColor(toast.type.color)
            
            Text(toast.message)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer(minLength: 8)
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minWidth: 280, maxWidth: 400)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(toast.type.color.opacity(0.3), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .padding(.bottom, 24)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                onDismiss()
            }
        }
    }
}

// Helper view for macOS blur/vibrancy effects (glassmorphism)
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
