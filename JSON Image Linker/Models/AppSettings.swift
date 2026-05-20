import Foundation

struct AppSettings: Codable, Equatable {
    var jsonFilename: String = "data.json"
    var imageFolderName: String = "images"
    var baseUrlTemplate: String = "https://01xharshu.github.io/image-prompt-api/images/"
    var enableExtraFields: Bool = false
    var includeFolderInJsonPath: Bool = true
    
    static let defaultSettings = AppSettings()
    
    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "com.harshu.JSON-Image-Linker.settings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return defaultSettings
        }
        return settings
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "com.harshu.JSON-Image-Linker.settings")
        }
    }
}
