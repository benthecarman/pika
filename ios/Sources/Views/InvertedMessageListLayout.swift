import UIKit

struct MessageCollectionLayoutMetrics: Equatable {
    let contentInset: UIEdgeInsets
    let scrollIndicatorInsets: UIEdgeInsets
}

enum MessageCollectionLayout {
    static func metrics(
        visualTopReserve: CGFloat,
        visualBottomReserve: CGFloat,
        safeAreaInsets: UIEdgeInsets
    ) -> MessageCollectionLayoutMetrics {
        let contentInset = UIEdgeInsets(
            top: visualTopReserve + safeAreaInsets.top,
            left: 0,
            bottom: visualBottomReserve + safeAreaInsets.bottom,
            right: 0
        )

        return MessageCollectionLayoutMetrics(
            contentInset: contentInset,
            scrollIndicatorInsets: contentInset
        )
    }

    static func isNearBottom(
        contentOffsetY: CGFloat,
        boundsHeight: CGFloat,
        contentHeight: CGFloat,
        adjustedInsets: UIEdgeInsets,
        tolerance: CGFloat = 50
    ) -> Bool {
        let visibleBottom = contentOffsetY + boundsHeight - adjustedInsets.bottom
        return visibleBottom >= contentHeight - tolerance
    }

    static func bottomContentOffset(
        contentHeight: CGFloat,
        boundsHeight: CGFloat,
        adjustedInsets: UIEdgeInsets
    ) -> CGPoint {
        let minOffsetY = -adjustedInsets.top
        let maxOffsetY = max(minOffsetY, contentHeight - boundsHeight + adjustedInsets.bottom)
        return CGPoint(x: 0, y: maxOffsetY)
    }
}
