import XCTest
import DaybookTestSupport

final class DaybookCoreTests: XCTestCase {
    func testSharedRegressionSuite() {
        for result in CoreChecks().run() {
            XCTAssertTrue(result.failures.isEmpty, "\(result.name): \(result.failures.joined(separator: "; "))")
        }
    }
}
