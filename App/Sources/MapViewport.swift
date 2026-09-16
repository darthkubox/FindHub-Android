// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import MapKit

enum MapViewport {
    static let deviceFocusMeters = 300.0

    /// Match the existing device focus scale, allowing MapKit's aspect-ratio fitting.
    static func isDeviceCloseUp(_ rect: MKMapRect?, at coordinate: CLLocationCoordinate2D) -> Bool {
        guard let rect, CLLocationCoordinate2DIsValid(coordinate),
              rect.width.isFinite, rect.height.isFinite, rect.width > 0, rect.height > 0 else { return false }
        let meters = min(rect.width, rect.height) * MKMetersPerMapPointAtLatitude(coordinate.latitude)
        return meters.isFinite && meters <= deviceFocusMeters * 1.1
    }

    /// Smallest wrapped rectangle containing the positions, with space for marker labels.
    static func bounds(for coordinates: [CLLocationCoordinate2D]) -> MKMapRect? {
        let points = coordinates.filter(CLLocationCoordinate2DIsValid).map(MKMapPoint.init)
            .filter { $0.x.isFinite && $0.y.isFinite }
        guard let first = points.first else { return nil }
        let world = MKMapSize.world.width
        let xs = points.map(\.x).sorted()
        var start = xs[0]
        var largestGap = -Double.infinity
        for i in xs.indices {
            let next = i + 1 < xs.count ? xs[i + 1] : xs[0] + world
            if next - xs[i] > largestGap {
                largestGap = next - xs[i]
                start = xs[(i + 1) % xs.count]
            }
        }
        let unwrapped = points.map { $0.x < start ? $0.x + world : $0.x }
        let minX = unwrapped.min()!, maxX = unwrapped.max()!
        let minY = points.map(\.y).min()!, maxY = points.map(\.y).max()!
        let minimum = MKMapPointsPerMeterAtLatitude(first.coordinate.latitude) * 250
        let width = max(maxX - minX, minimum) * 1.5
        let height = max(maxY - minY, minimum) * 1.5
        return MKMapRect(x: (minX + maxX - width) / 2, y: (minY + maxY - height) / 2,
                         width: width, height: height)
    }

    /// Like `bounds`, but keeps every device inside the band between the top bar
    /// (`topInset`) and the drawer (`bottomInset`) — never clipped at the top nor
    /// hidden behind the drawer. Builds a full-view-aspect rect with the content
    /// placed exactly in that visible band, so it works even when SwiftUI's Map
    /// ignores safe-area insets for `.rect` camera positions.
    static func overviewRect(for coordinates: [CLLocationCoordinate2D], viewSize: CGSize,
                             topInset: CGFloat, bottomInset: CGFloat) -> MKMapRect? {
        guard let content = bounds(for: coordinates) else { return nil }
        return bandRect(content: content, viewSize: viewSize, topInset: topInset, bottomInset: bottomInset)
    }

    /// A `meters`-wide close-up whose centre is `coordinate` in the middle of the
    /// visible band above the drawer — not the middle of the whole map view.
    static func focusRect(on coordinate: CLLocationCoordinate2D, meters: Double, viewSize: CGSize,
                          topInset: CGFloat, bottomInset: CGFloat) -> MKMapRect? {
        guard CLLocationCoordinate2DIsValid(coordinate), meters.isFinite, meters > 0 else { return nil }
        let point = MKMapPoint(coordinate)
        let side = meters * MKMapPointsPerMeterAtLatitude(coordinate.latitude)
        let content = MKMapRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)
        return bandRect(content: content, viewSize: viewSize, topInset: topInset, bottomInset: bottomInset)
    }

    private static func bandRect(content: MKMapRect, viewSize: CGSize,
                                 topInset: CGFloat, bottomInset: CGFloat) -> MKMapRect {
        let viewW = max(Double(viewSize.width), 1)
        let viewH = max(Double(viewSize.height), 1)
        let top = max(Double(topInset), 0)
        let bottom = max(Double(bottomInset), 0)
        let visibleH = max(viewH - top - bottom, viewH * 0.2)   // never reserve everything
        let visibleAspect = viewW / visibleH

        // Grow the content rect to the visible band's aspect ratio (fit whichever
        // axis is limiting), so scaling to the view leaves no cropping.
        var w = content.width, h = content.height
        if w / h < visibleAspect { w = h * visibleAspect } else { h = w / visibleAspect }
        let cx = content.midX, cy = content.midY

        // Full rect spans the whole view; place the content band at [top, viewH-bottom].
        let fullH = h * viewH / visibleH
        let originY = (cy - h / 2) - fullH * (top / viewH)
        return MKMapRect(x: cx - w / 2, y: originY, width: w, height: fullH)
    }
}
