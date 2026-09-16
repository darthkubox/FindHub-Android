// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import SwiftUI
@testable import FindHubAndroid

@MainActor
final class TabSelectionBox: ObservableObject {
    @Published var tab: MainTab = .devices
}

/// Hosts the real shell against an observable selection, so a test can switch
/// tabs through the same binding the navigation bar writes to.
private struct TabsHarness: View {
    @ObservedObject var model: AppModel
    @ObservedObject var box: TabSelectionBox

    var body: some View {
        MainTabsView(model: model, selection: $box.tab) {
            ToolbarItem(placement: .topBarTrailing) { Image(systemName: "person.crop.circle") }
        }
    }
}

/// Covers the two faults found on device: the page not following the selection,
/// and the home-indicator handle floating a whole safe-area inset too high.
final class TabBarTests: XCTestCase {

    @MainActor
    func testSwitchingTabsChangesThePageAndKeepsTheHandleOnTheBottomEdge() async throws {
        let model = AppModel()
        model.devices = [TrackerDevice(id: "fixture-wallet", name: "Portfel")]
        let box = TabSelectionBox()

        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; window.rootViewController = nil }
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = UIHostingController(rootView: TabsHarness(model: model, box: box))
        window.makeKeyAndVisible()

        let devicesShot = try await capture(window)
        box.tab = .places
        let placesShot = try await capture(window)

        // The page area above the navigation bar must actually change. Comparing
        // the whole window would pass on the bug, because the moving indicator
        // alone makes the images differ.
        let pageHeight = Int(Double(devicesShot.height) * 0.6)
        XCTAssertNotEqual(devicesShot.rows(0..<pageHeight), placesShot.rows(0..<pageHeight),
                          "Switching tabs left the page unchanged — selection and content are out of sync.")

        // The handle belongs on the window's bottom edge, where the system draws
        // its own: it sat 43pt up while the bar tried to paint from inside a
        // safeAreaInset, which cannot reach into the safe area.
        let handle = try XCTUnwrap(placesShot.handleOffsetFromBottom(),
                                   "No home-indicator handle was drawn at the bottom of the bar.")
        XCTAssertLessThanOrEqual(handle.top, 18.0, "Handle sits too high above the bottom edge.")
        XCTAssertGreaterThanOrEqual(handle.bottom, 4.0, "Handle is flush against the bottom edge.")
    }

    @MainActor
    private func capture(_ window: UIWindow) async throws -> Bitmap {
        try await Task.sleep(for: .milliseconds(700))
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        return try Bitmap(image)
    }
}

/// Raw pixels of a captured window, for the few geometric checks above.
private struct Bitmap {
    let width: Int, height: Int, scale: Double
    private let pixels: [UInt8]

    init(_ image: UIImage) throws {
        let cg = try XCTUnwrap(image.cgImage)
        width = cg.width; height = cg.height; scale = Double(image.scale)
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(data: &buffer, width: width, height: height,
                                              bitsPerComponent: 8, bytesPerRow: width * 4,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        pixels = buffer
    }

    func rows(_ range: Range<Int>) -> [UInt8] {
        Array(pixels[(range.lowerBound * width * 4)..<(range.upperBound * width * 4)])
    }

    /// Mean brightness across the middle of one row.
    private func brightness(row y: Int) -> Int {
        let x0 = width / 2 - 100, x1 = width / 2 + 100
        var sum = 0
        for x in x0..<x1 {
            let i = (y * width + x) * 4
            sum += Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2])
        }
        return sum / ((x1 - x0) * 3)
    }

    /// Distance in points from the window's bottom edge to the handle's edges.
    func handleOffsetFromBottom() -> (top: Double, bottom: Double)? {
        let searchDepth = min(height, Int(60 * scale))
        let surface = brightness(row: height - searchDepth)   // the bar behind the handle
        var rows: [Int] = []
        for y in (height - searchDepth)..<height where abs(brightness(row: y) - surface) > 20 {
            rows.append(height - 1 - y)
        }
        guard let nearest = rows.min(), let furthest = rows.max() else { return nil }
        return (top: Double(furthest) / scale, bottom: Double(nearest) / scale)
    }
}
