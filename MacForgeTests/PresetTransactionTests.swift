import XCTest
@testable import MacForge

final class PresetTransactionTests: XCTestCase {
    func testRecordsResultsInOrderAndRollbackMetadata() {
        var transaction = PresetTransaction(
            presetName: "Focus",
            oldStateSnapshot: ["Notch Shelf": "disabled"],
            actions: [.toggleNotchShelf(true)]
        )

        transaction.record(.success("First", "Done", reversible: true))
        transaction.record(.failure("Second", "Nope"))
        transaction.finish()

        XCTAssertEqual(transaction.results.map(\.title), ["First", "Second"])
        XCTAssertTrue(transaction.rollbackAvailable)
        XCTAssertNotNil(transaction.finishedAt)
    }
}
