//
//  ProjectService.swift
//  femi
//
//  Local project storage boundary. Every save and read goes through here;
//  nothing in this module touches the network or upload API.
//

import Foundation
import ImageIO

enum ProjectService {
    private static let projectKey = "Project"

    /// App sandbox `Documents/`.
    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    /// ID of the currently-selected project.
    static var current: String? {
        get { UserDefaults.standard.string(forKey: projectKey) }
        set {
            if let v = newValue { UserDefaults.standard.set(v, forKey: projectKey) }
            else { UserDefaults.standard.removeObject(forKey: projectKey) }
        }
    }

    /// Ensure the current project exists on disk. On first launch, claims
    /// `"1"` if nothing is set. Idempotent.
    static func ensureCurrentProject() {
        if current == nil {
            current = "1"
        }
        let dir = documents.appendingPathComponent(current!)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir,
                                                     withIntermediateDirectories: true)
        }
    }

    /// Embed XMP metadata (prompt + model) into the image bytes and optionally
    /// persist them to the current project's folder.
    ///
    /// Always returns the (possibly metadata-embedded) bytes. When `persist`
    /// is true (default), the embedded bytes are also written to
    /// `Documents/<projectId>/<file>`. When both `prompt` and `model` are nil,
    /// the input is returned unchanged.
    @discardableResult
    static func saveFile(
        _ data: Data,
        named file: String,
        prompt: String? = nil,
        model: String? = nil,
        persist: Bool = true
    ) -> Data {
        let out: Data
        if prompt == nil && model == nil {
            out = data
        } else {
            let source = CGImageSourceCreateWithData(data as CFData, nil)!
            let type = CGImageSourceGetType(source)!

            let metadata = CGImageMetadataCreateMutable()
            registerNamespace(metadata, uri: iptcExtURI, prefix: "iptcExt")
            registerNamespace(metadata, uri: dcURI, prefix: "dc")
            registerNamespace(metadata, uri: xmpURI, prefix: "xmp")
            if let prompt {
                setProperty(metadata, prefix: "dc", path: "description", value: prompt, file: file)
                setProperty(metadata, prefix: "iptcExt", path: "AIPromptInformation", value: prompt, file: file)
            }
            if let model {
                setProperty(metadata, prefix: "xmp", path: "CreatorTool", value: model, file: file)
                setProperty(metadata, prefix: "iptcExt", path: "AISystemUsed", value: model, file: file)
            }

            let buffer = NSMutableData()
            let cgDest = CGImageDestinationCreateWithData(buffer as CFMutableData, type, 1, nil)!
            var error: Unmanaged<CFError>?
            let ok = CGImageDestinationCopyImageSource(
                cgDest, source,
                [kCGImageDestinationMetadata: metadata,
                 kCGImageDestinationMergeMetadata: true] as CFDictionary,
                &error
            )
            precondition(ok, "CopyImageSource failed for \(file): \(error?.takeRetainedValue().localizedDescription ?? "nil")")
            precondition(CGImageDestinationFinalize(cgDest), "Finalize failed for \(file)")
            out = buffer as Data
        }

        if persist {
            let dest = getUrl(for: file)
            let ext = URL(fileURLWithPath: file).pathExtension
            var tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            if !ext.isEmpty { tempURL.appendPathExtension(ext) }
            try! out.write(to: tempURL)
            if FileManager.default.fileExists(atPath: dest.path) {
                _ = try! FileManager.default.replaceItemAt(dest, withItemAt: tempURL)
            } else {
                try! FileManager.default.moveItem(at: tempURL, to: dest)
            }
            precondition(
                FileManager.default.fileExists(atPath: dest.path),
                "saveFile: file not present after move at \(dest.path)"
            )
        }
        return out
    }

    private static func registerNamespace(_ metadata: CGMutableImageMetadata, uri: String, prefix: String) {
        precondition(
            CGImageMetadataRegisterNamespaceForPrefix(
                metadata, uri as CFString, prefix as CFString, nil
            ),
            "\(prefix) namespace register failed"
        )
    }

    private static func setProperty(
        _ metadata: CGMutableImageMetadata,
        prefix: String,
        path: String,
        value: String,
        file: String
    ) {
        let uri: String = switch prefix {
        case "dc": dcURI
        case "xmp": xmpURI
        case "iptcExt": iptcExtURI
        default: preconditionFailure("unknown XMP prefix \(prefix)")
        }
        let xmpTag = CGImageMetadataTagCreate(
            uri as CFString,
            prefix as CFString,
            path as CFString,
            .default,
            value as CFString
        )!
        precondition(
            CGImageMetadataSetTagWithPath(metadata, nil, "\(prefix):\(path)" as CFString, xmpTag),
            "\(prefix):\(path) set failed for \(file)"
        )
    }

    /// Set the like state by writing `xmp:Rating` (5 = liked, 0 = not).
    /// Atomic: every step completes or the function crashes.
    static func like(_ file: String, _ liked: Bool) {
        let url = getUrl(for: file)
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        let type = CGImageSourceGetType(source)!

        let metadata = CGImageMetadataCreateMutable()
        registerNamespace(metadata, uri: xmpURI, prefix: "xmp")
        let value = (liked ? 5 : 0) as CFNumber
        let tag = CGImageMetadataTagCreate(
            xmpURI as CFString,
            "xmp" as CFString,
            "Rating" as CFString,
            .default,
            value
        )!
        precondition(
            CGImageMetadataSetTagWithPath(metadata, nil, "xmp:Rating" as CFString, tag),
            "xmp:Rating set failed for \(file)"
        )

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(url.pathExtension)
        let dest = CGImageDestinationCreateWithURL(tempURL as CFURL, type, 1, nil)!
        var error: Unmanaged<CFError>?
        let ok = CGImageDestinationCopyImageSource(
            dest, source,
            [kCGImageDestinationMetadata: metadata,
             kCGImageDestinationMergeMetadata: true] as CFDictionary,
            &error
        )
        precondition(ok, "CopyImageSource failed for \(file): \(error?.takeRetainedValue().localizedDescription ?? "nil")")

        try! FileManager.default.replaceItemAt(url, withItemAt: tempURL)

        let verifySource = CGImageSourceCreateWithURL(url as CFURL, nil)!
        let verifyMetadata = CGImageSourceCopyMetadataAtIndex(verifySource, 0, nil)!
        let verifyTag = CGImageMetadataCopyTagWithPath(verifyMetadata, nil, "xmp:Rating" as CFString)!
        let verifyValue = CGImageMetadataTagCopyValue(verifyTag)!
        let expected = liked ? 5 : 0
        let actual = (verifyValue as? NSNumber)?.intValue
            ?? Int(verifyValue as? String ?? "") ?? -1
        precondition(actual == expected,
                     "xmp:Rating verify failed for \(file): expected \(expected), got \(verifyValue)")
    }

    /// List every file in the current project's folder.
    static func getAllGenerations() -> [URL] {
        ensureCurrentProject()
        let dir = documents.appendingPathComponent(current!)
        return (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        )) ?? []
    }

    /// Read `dc:description` from an image. Nil when absent.
    static func getPrompt(_ file: String) -> String? {
        readStringProperty(file, path: "dc:description")
    }

    /// Read `xmp:CreatorTool` from an image. Nil when absent.
    static func getModel(_ file: String) -> String? {
        readStringProperty(file, path: "xmp:CreatorTool")
    }

    /// Read the like state of an image from its `xmp:Rating` (`>= 1` = liked).
    static func getLike(_ file: String) -> Bool {
        let url = getUrl(for: file)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil),
              let tag = CGImageMetadataCopyTagWithPath(metadata, nil, "xmp:Rating" as CFString) else {
            return false
        }
        let value = CGImageMetadataTagCopyValue(tag)
        let intValue = (value as? NSNumber)?.intValue
            ?? Int(value as? String ?? "") ?? 0
        return intValue >= 1
    }

    private static let dcURI = "http://purl.org/dc/elements/1.1/"
    private static let xmpURI = "http://ns.adobe.com/xap/1.0/"
    private static let iptcExtURI = "http://iptc.org/std/Iptc4xmpExt/2008-02-29/"

    private static func readStringProperty(_ file: String, path: String) -> String? {
        let url = getUrl(for: file)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil),
              let tag = CGImageMetadataCopyTagWithPath(metadata, nil, path as CFString) else {
            return nil
        }
        let value = CGImageMetadataTagCopyValue(tag)
        let string = (value as? String) ?? (value as? NSString).map(String.init)
        guard let string, !string.isEmpty else { return nil }
        return string
    }

    private static func getUrl(for file: String) -> URL {
        ensureCurrentProject()
        return documents
            .appendingPathComponent(current!)
            .appendingPathComponent(URL(fileURLWithPath: file).lastPathComponent)
    }
}
