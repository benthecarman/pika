import XCTest
@testable import Pika

final class MessageCollectionLayoutTests: XCTestCase {
    func testMetricsMatchVisualReservesForNormalScrollDirection() {
        let metrics = MessageCollectionLayout.metrics(
            visualTopReserve: 18,
            visualBottomReserve: 72,
            safeAreaInsets: UIEdgeInsets(top: 12, left: 0, bottom: 34, right: 0)
        )

        XCTAssertEqual(metrics.contentInset.top, 30)
        XCTAssertEqual(metrics.contentInset.bottom, 106)
        XCTAssertEqual(metrics.scrollIndicatorInsets.top, 30)
        XCTAssertEqual(metrics.scrollIndicatorInsets.bottom, 106)
    }

    func testNearBottomUsesVisibleViewportBottom() {
        let insets = UIEdgeInsets(top: 30, left: 0, bottom: 106, right: 0)

        XCTAssertTrue(
            MessageCollectionLayout.isNearBottom(
                contentOffsetY: 900,
                boundsHeight: 500,
                contentHeight: 1300,
                adjustedInsets: insets
            )
        )
        XCTAssertFalse(
            MessageCollectionLayout.isNearBottom(
                contentOffsetY: 700,
                boundsHeight: 500,
                contentHeight: 1300,
                adjustedInsets: insets
            )
        )
    }

    func testBottomContentOffsetRespectsInsets() {
        let offset = MessageCollectionLayout.bottomContentOffset(
            contentHeight: 1300,
            boundsHeight: 500,
            adjustedInsets: UIEdgeInsets(top: 30, left: 0, bottom: 106, right: 0)
        )
        XCTAssertEqual(offset, CGPoint(x: 0, y: 906))
    }
}
