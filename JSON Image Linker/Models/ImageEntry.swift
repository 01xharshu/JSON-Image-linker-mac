import Foundation

struct ImageEntry: Codable, Identifiable, Hashable {
    var id: String { image }
    var image: String // e.g. "images/photo.png" or "photo.png"
    var prompt: String
    
    // Optional fields (toggled via settings)
    var title: String?
    var author: String?
    var tags: [String]?
    
    // Helper helper to get only the filename (e.g., "photo")
    var filenameOnly: String {
        let filename = URL(fileURLWithPath: image).lastPathComponent
        return URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
    }
    
    // Helper to get only the extension (e.g., "png")
    var fileExtension: String {
        return URL(fileURLWithPath: image).pathExtension
    }
    
    // Dynamic decoding to be highly resilient to extra JSON fields
    enum CodingKeys: String, CodingKey {
        case image
        case prompt
        case title
        case author
        case tags
    }
    
    init(image: String, prompt: String, title: String? = nil, author: String? = nil, tags: [String]? = nil) {
        self.image = image
        self.prompt = prompt
        self.title = title
        self.author = author
        self.tags = tags
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.image = try container.decode(String.self, forKey: .image)
        self.prompt = try container.decode(String.self, forKey: .prompt)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.author = try container.decodeIfPresent(String.self, forKey: .author)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags)
    }
}
