import Foundation
import UniformTypeIdentifiers

public enum MIME {
    /// Try manual mime override first (if provided), else auto-detect from file extension.
    public static func mimeType(for fileURL: URL, manual: String? = nil) -> String {
        if let m = manual, !m.isEmpty { return m }
        if let ext = fileURL.pathExtension.split(separator: ".").last.map(String.init),
           !ext.isEmpty,
           #available(iOS 14.0, macOS 11.0, *) {
            if let ut = UTType(filenameExtension: ext), let mime = ut.preferredMIMEType {
                return mime
            }
        } else {
            // fallback common map
            let lower = fileURL.pathExtension.lowercased()
            if !lower.isEmpty, let fallback = fallbackMimeTypes[lower] {
                return fallback
            }
        }
        // default
        return "application/octet-stream"
    }

    private static let fallbackMimeTypes: [String: String] = [
        "jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png", "gif": "image/gif",
        "json": "application/json", "txt": "text/plain", "pdf": "application/pdf",
        "zip": "application/zip", "csv": "text/csv"
    ]
}
