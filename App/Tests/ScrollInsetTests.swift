// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import SwiftUI
@testable import FindHubAndroid

/// Same shell as MainTabsView, with a pushed-style detail screen as the page.
private struct DetailInShell: View {
    @ObservedObject var model: AppModel
    let device: TrackerDevice
    @State private var selection: MainTab = .devices
    let safeBottom: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack { DeviceDetailView(model: model, device: device) }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: M3TabBar.totalHeight(safeBottom: safeBottom))
                }
                .environment(\.tabBarReserve, M3TabBar.totalHeight(safeBottom: safeBottom))
            M3TabBar(selection: $selection, safeBottom: safeBottom)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

/// Scrolled to the end, the last card of a detail screen must clear the
/// navigation bar instead of ending underneath it.
final class ScrollInsetTests: XCTestCase {
    @MainActor
    func testDeviceDetailEndsAboveNavigationBar() async throws {
        let model = AppModel()
        let device = TrackerDevice(id: "fixture-scroll", name: "Galaxy S22+")
        model.devices = [device]
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; window.rootViewController = nil }
        window.overrideUserInterfaceStyle = .dark
        let safeBottom = ScreenInsets.bottom
        window.rootViewController = UIHostingController(rootView: DetailInShell(model: model, device: device, safeBottom: safeBottom))
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(900))

        let scroll = try XCTUnwrap(Self.scrollViews(in: window).max { $0.contentSize.height < $1.contentSize.height })
        let maxOffset = scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom
        scroll.setContentOffset(CGPoint(x: 0, y: max(maxOffset, -scroll.adjustedContentInset.top)), animated: false)
        try await Task.sleep(for: .milliseconds(500))
        window.layoutIfNeeded()

        let contentEnd = scroll.convert(CGPoint(x: 0, y: scroll.contentSize.height), to: window).y
        let barTop = window.bounds.height - M3TabBar.totalHeight(safeBottom: safeBottom)
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image); attachment.name = "device-detail-bottom"; attachment.lifetime = .keepAlways; add(attachment)
        if let dir = ProcessInfo.processInfo.environment["MOTOHUB_SNAPSHOT_DIR"], let png = image.pngData() {
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("device-detail-bottom.png"))
        }
        XCTAssertLessThanOrEqual(contentEnd, barTop + 1,
                                 "Scrolled to the end, content still ends \(contentEnd - barTop) pt under the navigation bar")
        XCTAssertGreaterThanOrEqual(contentEnd, barTop - 60, "An oversized empty gap is left above the navigation bar")
    }

    @MainActor
    private static func scrollViews(in view: UIView) -> [UIScrollView] {
        (view as? UIScrollView).map { [$0] } ?? [] + view.subviews.flatMap { scrollViews(in: $0) }
    }
}
