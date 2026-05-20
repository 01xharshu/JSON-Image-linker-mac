import AppKit

extension NSImage {
    func fileData(for extensionStr: String) -> Data? {
        guard let tiff = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        
        let ext = extensionStr.lowercased()
        if ext == "png" {
            return bitmap.representation(using: .png, properties: [:])
        } else if ext == "jpg" || ext == "jpeg" {
            return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        } else if ext == "gif" {
            return bitmap.representation(using: .gif, properties: [:])
        } else if ext == "bmp" {
            return bitmap.representation(using: .bmp, properties: [:])
        } else if ext == "tiff" || ext == "tif" {
            return tiff
        }
        // Fallback to PNG
        return bitmap.representation(using: .png, properties: [:])
    }
}
