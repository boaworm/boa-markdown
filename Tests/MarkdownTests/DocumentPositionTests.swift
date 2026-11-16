import XCTest

final class DocumentPositionTests: XCTestCase {
    func testRequestsArePerFileLatestWinsAndConsumeOnce() {
        let store = DocumentPositionStore()
        let a = URL(fileURLWithPath: "/tmp/a.md"), b = URL(fileURLWithPath: "/tmp/b.md")
        store.set(.line(1), for: a)
        let stale = store.set(.line(2), for: a)
        store.set(.anchor("section"), for: a)
        store.discard(for: a, id: stale)
        store.set(.line(10), for: b)
        XCTAssertEqual(store.consume(for: a), .anchor("section"))
        XCTAssertNil(store.consume(for: a))
        XCTAssertEqual(store.consume(for: b), .line(10))
    }

    func testPositionEncodingDoesNotGenerateExecutableUserInput() throws {
        let target = DocumentPosition.anchor("\";alert(1);//")
        let encoded = try JSONSerialization.data(withJSONObject: target.arguments)
        let object = try JSONSerialization.jsonObject(with: encoded) as! [String: String]
        XCTAssertEqual(object["anchor"], "\";alert(1);//")
    }
}
