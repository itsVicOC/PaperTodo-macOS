import CoreGraphics

public enum ScreenPlacement {
    public static func bestScreenIndex(for frame: CGRect, screens: [CGRect]) -> Int? {
        guard !screens.isEmpty else { return nil }

        let intersections = screens.enumerated().map { index, screen in
            (index: index, area: frame.intersection(screen).area)
        }
        if let bestIntersection = intersections.max(by: { $0.area < $1.area }),
           bestIntersection.area > 0 {
            return bestIntersection.index
        }

        let center = CGPoint(x: frame.midX, y: frame.midY)
        return screens.enumerated().min { lhs, rhs in
            center.squaredDistance(to: lhs.element.center) < center.squaredDistance(to: rhs.element.center)
        }?.offset
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else { return 0 }
        return width * height
    }

    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

private extension CGPoint {
    func squaredDistance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return dx * dx + dy * dy
    }
}
