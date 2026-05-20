import SwiftUI

@main
struct JSON_Image_LinkerApp: App {
    @StateObject private var appViewModel = AppViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainView(viewModel: appViewModel)
                .frame(minWidth: 900, minHeight: 600)
                .navigationTitle(
                    appViewModel.workingFolderURL != nil 
                        ? "JSON Image Linker — \(appViewModel.workingFolderURL!.lastPathComponent)" 
                        : "JSON Image Linker"
                )
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // Custom macOS Menu commands
            CommandGroup(replacing: .newItem) {
                Button("Select Working Folder...") {
                    appViewModel.selectFolder()
                }
                .keyboardShortcut("o", modifiers: .command)
                
                if appViewModel.workingFolderURL != nil {
                    Button("Disconnect Working Folder") {
                        appViewModel.clearFolder()
                    }
                    .keyboardShortcut("d", modifiers: .command)
                }
            }
            
            SidebarCommands()
        }
        
        // Native macOS Settings (App Menu -> Preferences or Command + ,)
        Settings {
            SettingsView(viewModel: appViewModel)
        }
    }
}
