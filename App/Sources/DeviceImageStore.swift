// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

/// Per-device custom photos (like Find Hub's device image), saved to Documents
/// keyed by canonic id. Purely local to the device.
enum DeviceImageStore {
    private static var dir: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("DeviceImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private static func url(for id: String) -> URL {
        let safe = id.replacingOccurrences(of: "/", with: "_")
        return dir.appendingPathComponent("\(safe).jpg")
    }

    static func image(for id: String) -> UIImage? {
        guard let data = try? Data(contentsOf: url(for: id)) else { return nil }
        return UIImage(data: data)
    }

    static func remove(_ id: String) {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    static func save(_ image: UIImage, for id: String) {
        // Downscale to a reasonable thumbnail before storing.
        let target: CGFloat = 240
        let scale = min(target / image.size.width, target / image.size.height, 1)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let rendered = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        if let data = rendered.jpegData(compressionQuality: 0.85) {
            try? data.write(to: url(for: id))
        }
    }
}
