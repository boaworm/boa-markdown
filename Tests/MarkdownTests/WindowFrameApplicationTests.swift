import AppKit
import XCTest

final class WindowFrameApplicationTests: XCTestCase {
    @MainActor func testLaterPlacementCancelsEarlierDelayedRestore() {
        let visible = CGRect(x: 0, y: 0, width: 1500, height: 900)
        let old = CGRect(x: 40, y: 50, width: 800, height: 600)
        let latest = CGRect(x: 300, y: 80, width: 1000, height: 700)
        let window = NSWindow(contentRect: old, styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        defer { window.orderOut(nil) }
        WindowAccessor.applyFrameApplications(to: window, targetFrame: old, visibleFrames: [visible])
        WindowAccessor.applyFrameApplications(to: window, targetFrame: latest, visibleFrames: [visible])
        let settled = expectation(description: "old restore has expired")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            XCTAssertEqual(window.frame, latest)
            settled.fulfill()
        }
        wait(for: [settled], timeout: 2)
    }
}
