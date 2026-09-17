// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import MapKit

enum MapMarkerID: Hashable {
    case user
    case device(String)

    var sortKey: String {
        switch self { case .user: return "0"; case .device(let id): return "1" + id }
    }
}

struct MapCluster: Identifiable {
    let members: [MapMarkerID]
    let coordinate: CLLocationCoordinate2D
    var id: [MapMarkerID] { members }
}

enum MapClusters {
    static let tileWidth = 60.0
    static let tileHeight = 56.0
    static let spacing = 4.0
    static let padding = 8.0
    static let tipHeight = 10.0

    static func size(count: Int) -> CGSize {
        let columns = min(3, max(1, count))
        let rows = max(1, (count + columns - 1) / columns)
        return CGSize(width: Double(columns) * tileWidth + Double(columns - 1) * spacing + 2 * padding,
                      height: Double(rows) * tileHeight + Double(rows - 1) * spacing + 2 * padding + tipHeight)
    }

    /// Merge overlapping on-screen marker frames; zooming in separates them again.
    static func make(positions: [MapMarkerID: CLLocationCoordinate2D],
                     visibleMapWidth: Double, screenWidth: Double) -> [MapCluster] {
        let valid = positions.filter { CLLocationCoordinate2DIsValid($0.value) }
        let ids = valid.keys.sorted { $0.sortKey < $1.sortKey }
        guard let first = ids.first else { return [] }
        let originX = MKMapPoint(valid[first]!).x
        let world = MKMapSize.world.width
        let points = valid.mapValues { coordinate -> MKMapPoint in
            let p = MKMapPoint(coordinate)
            let x = p.x + ((originX - p.x) / world).rounded() * world
            return MKMapPoint(x: x, y: p.y)
        }
        let scale = max(visibleMapWidth / max(screenWidth, 1), 0.001)
        var groups = ids.map { [$0] }
        func center(_ members: [MapMarkerID]) -> MKMapPoint {
            MKMapPoint(x: members.reduce(0) { $0 + points[$1]!.x } / Double(members.count),
                       y: members.reduce(0) { $0 + points[$1]!.y } / Double(members.count))
        }
        func frame(_ members: [MapMarkerID]) -> CGRect {
            let p = center(members), s = size(count: members.count)
            return CGRect(x: p.x / scale - s.width / 2, y: p.y / scale - s.height,
                          width: s.width, height: s.height).insetBy(dx: -5, dy: -5)
        }
        var merged = true
        while merged {
            merged = false
            outer: for i in groups.indices {
                for j in groups.indices where j > i {
                    if frame(groups[i]).intersects(frame(groups[j])) {
                        let other = groups.remove(at: j)
                        groups[i] += other
                        merged = true
                        break outer
                    }
                }
            }
        }
        return groups.map { members in
            let p = center(members)
            let x = (p.x.truncatingRemainder(dividingBy: world) + world).truncatingRemainder(dividingBy: world)
            return MapCluster(members: members.sorted { $0.sortKey < $1.sortKey },
                              coordinate: MKMapPoint(x: x, y: p.y).coordinate)
        }
    }
}
