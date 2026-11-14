import XCTest

@MainActor
final class WindowSizePersistenceTests: XCTestCase {

    // MARK: - Host App Window Frame Tests

    func testHostWindowFrameParsing_AcceptsIntegerValuesFromDefaultsCli() {
        let frame = AppearancePreference.hostWindowFrame(from: ["x": 180, "y": 162, "w": 1_040, "h": 680])

        XCTAssertEqual(frame, CGRect(x: 180, y: 162, width: 1_040, height: 680))
    }

    func testHostWindowFrameParsing_AcceptsStringValuesFromDefaultsCli() {
        let frame = AppearancePreference.hostWindowFrame(from: ["x": "180.0", "y": "162.0", "w": "1040.0", "h": "680.0"])

        XCTAssertEqual(frame, CGRect(x: 180, y: 162, width: 1_040, height: 680))
    }

    func testHostDefaultFrame_UsesCurrentWidthAndEightyPercentVisibleHeight() {
        let visibleFrame = CGRect(x: 100, y: 50, width: 1440, height: 900)
        let currentFrame = CGRect(x: 0, y: 0, width: 1000, height: 480)

        let defaultFrame = WindowAccessor.defaultDocumentFrame(
            currentFrame: currentFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(defaultFrame.width, 1000, "Default width should preserve current SwiftUI/window width")
        XCTAssertEqual(defaultFrame.height, 720, "Default height should leave 15% top and 5% bottom margins")
        XCTAssertEqual(defaultFrame.minY, 95, "Default y should leave a 5% bottom margin")
        XCTAssertEqual(defaultFrame.maxY, 815, "Default maxY should leave a 15% top margin")
        XCTAssertEqual(defaultFrame.midX, visibleFrame.midX, "Default frame should stay horizontally centered")
    }

    func testHostDefaultFrame_ClampsCurrentWidthToVisibleFrameWithoutChangingPolicy() {
        let visibleFrame = CGRect(x: -1200, y: 0, width: 900, height: 1000)
        let currentFrame = CGRect(x: 0, y: 0, width: 1200, height: 500)

        let defaultFrame = WindowAccessor.defaultDocumentFrame(
            currentFrame: currentFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(defaultFrame.width, 900, "Default frame should not exceed the target screen width")
        XCTAssertEqual(defaultFrame.height, 800)
        XCTAssertEqual(defaultFrame.minX, visibleFrame.minX)
        XCTAssertEqual(defaultFrame.minY, 50)
    }

    func testHostFrameValidation_RejectsTinyAndNonFiniteFrames() {
        let invalidFrames = [
            CGRect(x: 0, y: 0, width: 203, height: 269),
            CGRect(x: 0, y: 0, width: 1000, height: 199),
            CGRect(x: 0, y: 0, width: 319, height: 800),
            CGRect(x: 0, y: 0, width: CGFloat.nan, height: 800),
            CGRect.null
        ]

        for frame in invalidFrames {
            XCTAssertFalse(
                WindowAccessor.isFrameValidForRestore(frame),
                "Frame \(frame) should be rejected for host window restore"
            )
        }
    }

    func testHostFrameValidation_AcceptsReasonableFrames() {
        let validFrame = CGRect(x: 120, y: 80, width: 1000, height: 720)

        XCTAssertTrue(WindowAccessor.isFrameValidForRestore(validFrame))
    }

    func testHostFrameRestorable_RejectsFramesOutsideCurrentScreens() {
        let savedFrame = CGRect(x: 2_000, y: 2_000, width: 1_000, height: 720)
        let currentScreens = [CGRect(x: 0, y: 0, width: 1440, height: 900)]

        XCTAssertFalse(
            WindowAccessor.isFrameRestorable(savedFrame, visibleFrames: currentScreens),
            "Saved frames from a disconnected monitor should be ignored and replaced with a default frame"
        )
    }

    func testHostFrameRestorable_RejectsNonIntersectingFramesInsteadOfTreatingNullIntersectionAsUsable() {
        let savedFrame = CGRect(x: 180, y: 162, width: 1_040, height: 680)
        let visibleFrames = [CGRect(x: 0, y: 0, width: 1_512, height: 130)]

        XCTAssertFalse(
            WindowAccessor.isFrameRestorable(savedFrame, visibleFrames: visibleFrames),
            "Null intersections report infinite dimensions on CGRect; they must not make a disconnected frame look restorable"
        )
    }

    func testHostFrameRestorable_AcceptsFramesWithUsableVisibleIntersection() {
        let savedFrame = CGRect(x: 1_100, y: 100, width: 1_000, height: 720)
        let currentScreens = [CGRect(x: 0, y: 0, width: 1_512, height: 949)]

        XCTAssertTrue(
            WindowAccessor.isFrameRestorable(savedFrame, visibleFrames: currentScreens),
            "A saved frame should restore when at least the minimum usable area is visible"
        )
    }

    func testInitialDocumentContentSize_UsesSavedRestorableFrameBeforeWindowAttach() {
        let savedFrame = CGRect(x: 180, y: 162, width: 1_040, height: 680)
        let visibleFrames = [CGRect(x: 0, y: 0, width: 1_512, height: 949)]

        let initialSize = WindowAccessor.initialDocumentContentSize(
            savedFrame: savedFrame,
            visibleFrames: visibleFrames
        )

        XCTAssertEqual(initialSize, WindowAccessor.contentSize(forWindowFrame: savedFrame))
        XCTAssertLessThan(initialSize.height, savedFrame.height)
    }

    func testInitialDocumentContentSize_FallsBackWhenSavedFrameIsOffscreen() {
        let savedFrame = CGRect(x: 3_000, y: 3_000, width: 1_040, height: 680)
        let visibleFrames = [CGRect(x: 0, y: 0, width: 1_512, height: 949)]

        let initialSize = WindowAccessor.initialDocumentContentSize(
            savedFrame: savedFrame,
            visibleFrames: visibleFrames
        )

        XCTAssertEqual(initialSize, CGSize(width: 1_000, height: 800))
    }

    func testHostFrameApplication_ReappliesDefaultWhenLaterWindowSizingOverwritesInitialFrame() {
        let visibleFrame = CGRect(x: 1_512, y: -98, width: 1_920, height: 1_080)
        let initialSwiftUIFrame = CGRect(x: 1_944, y: 397, width: 900, height: 450)
        let expectedDefaultFrame = WindowAccessor.defaultDocumentFrame(
            currentFrame: initialSwiftUIFrame,
            visibleFrame: visibleFrame
        )

        let actions = WindowAccessor.defaultFrameApplications(
            currentFrame: initialSwiftUIFrame,
            targetFrame: expectedDefaultFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(actions.count, 3, "SwiftUI can overwrite early document frame passes; schedule bounded reapplies")
        XCTAssertEqual(actions[0].delay, 0)
        XCTAssertEqual(actions[0].frame, expectedDefaultFrame)
        XCTAssertEqual(actions[1].delay, 0.20)
        XCTAssertEqual(actions[1].frame, expectedDefaultFrame)
        XCTAssertEqual(actions[2].delay, 0.80)
        XCTAssertEqual(actions[2].frame, expectedDefaultFrame)
    }

    func testHostFrameApplication_DelayedReapplyKeepsTargetWhenStartupFrameDrifts() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_512, height: 949)
        let initialSwiftUIFrame = CGRect(x: 306, y: 298, width: 900, height: 450)
        let expectedDefaultFrame = WindowAccessor.defaultDocumentFrame(
            currentFrame: initialSwiftUIFrame,
            visibleFrame: visibleFrame
        )

        let actions = WindowAccessor.defaultFrameApplications(
            currentFrame: initialSwiftUIFrame,
            targetFrame: expectedDefaultFrame,
            visibleFrame: visibleFrame
        )

        let delayedActions = actions.dropFirst()
        XCTAssertFalse(delayedActions.isEmpty)
        for action in delayedActions {
            XCTAssertEqual(
                action.frame,
                expectedDefaultFrame,
                "Delayed startup reapplies should keep targeting the chosen startup frame even if SwiftUI applies another transient size"
            )
        }
    }

    func testHostFrameApplication_DoesNotLoopWhenWindowAlreadyMatchesTarget() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_512, height: 949)
        let targetFrame = CGRect(x: 306, y: 47.45, width: 900, height: 759.2)

        let actions = WindowAccessor.defaultFrameApplications(
            currentFrame: targetFrame,
            targetFrame: targetFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(actions.count, 1)
        XCTAssertEqual(actions[0].delay, 0)
        XCTAssertEqual(actions[0].frame, targetFrame)
    }

    func testHostFrameApplication_CancelsDelayedReapplyAfterWindowEntersFullScreen() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_512, height: 949)
        let restoredWindowFrame = CGRect(x: 256, y: 120, width: 1_000, height: 720)
        let fullScreenFrame = CGRect(x: 0, y: 0, width: 1_512, height: 982)
        let window = NSWindow(
            contentRect: CGRect(x: 300, y: 180, width: 900, height: 600),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        var isFullScreenContext = false

        WindowAccessor.applyFrameApplications(
            to: window,
            targetFrame: restoredWindowFrame,
            visibleFrames: [visibleFrame],
            fullScreenContextProvider: { _ in isFullScreenContext }
        )
        XCTAssertEqual(window.frame, restoredWindowFrame)

        isFullScreenContext = true
        window.setFrame(fullScreenFrame, display: false)

        let delayedRestoresFinished = expectation(description: "Both delayed startup frame restores have fired")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            XCTAssertEqual(
                window.frame,
                fullScreenFrame,
                "A delayed windowed-frame restore must not resize a document after it enters full screen"
            )
            delayedRestoresFinished.fulfill()
        }
        wait(for: [delayedRestoresFinished], timeout: 1.5)
    }

    func testHostWindowFrameSave_IgnoresUntitledAccessoryWindows() {
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 900, height: 450), styleMask: [], backing: .buffered, defer: false)

        XCTAssertFalse(
            WindowAccessor.shouldSaveFrame(for: window),
            "Hidden accessory windows created during document launch should not overwrite the persisted document frame"
        )
    }

    func testHostWindowFrameSave_AcceptsDocumentWindows() {
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 900, height: 450), styleMask: [], backing: .buffered, defer: false)
        window.representedURL = URL(fileURLWithPath: "/tmp/README.md")

        XCTAssertTrue(WindowAccessor.shouldSaveFrame(for: window))
    }

    func testHostFullScreenContext_DetectsWindowAndTabbedWindowStyleMasks() {
        XCTAssertTrue(
            WindowAccessor.isInFullScreenContext(
                styleMask: [.titled, .fullScreen],
                tabbedWindowStyleMasks: []
            )
        )
        XCTAssertTrue(
            WindowAccessor.isInFullScreenContext(
                styleMask: [.titled],
                tabbedWindowStyleMasks: [[.titled], [.titled, .fullScreen]]
            ),
            "A newly opened tab must inherit the full-screen context before delayed frame restoration runs"
        )
    }

    func testHostFullScreenContext_AcceptsWindowedDocumentGroup() {
        XCTAssertFalse(
            WindowAccessor.isInFullScreenContext(
                styleMask: [.titled, .resizable],
                tabbedWindowStyleMasks: [[.titled, .resizable]]
            )
        )
    }

    func testHostWindowFrameSave_RejectsFullScreenDocumentWindows() {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 1_512, height: 949),
            styleMask: [.titled, .resizable, .fullScreen],
            backing: .buffered,
            defer: false
        )
        window.representedURL = URL(fileURLWithPath: "/tmp/README.md")

        XCTAssertFalse(
            WindowAccessor.shouldSaveFrame(for: window),
            "Full-screen geometry must not overwrite the persisted windowed frame"
        )
    }

    func testHostWindowFrameSave_RejectsFullScreenTransitionFrames() {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 1_200, height: 800),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.representedURL = URL(fileURLWithPath: "/tmp/README.md")

        XCTAssertFalse(
            WindowAccessor.shouldSaveFrame(
                for: window,
                isFullScreenTransitionInProgress: true
            ),
            "Transient geometry during full-screen entry or exit must not be persisted"
        )
    }

}

extension WindowSizePersistenceTests {
    func testCrossScreenMoveRestoresPreMoveSizeAndKeepsDraggedOrigin() {
        let before = CGRect(x: 100, y: 100, width: 1200, height: 800)
        let systemAdjusted = CGRect(x: 2100, y: 120, width: 600, height: 400)
        let preserved = WindowAccessor.framePreservingSizeAcrossScreens(
            currentFrame: systemAdjusted,
            frameBeforeMove: before,
            previousScreenID: 1,
            currentScreenID: 2,
            isLiveResize: false,
            isFullScreen: false
        )
        XCTAssertEqual(preserved, CGRect(x: 2100, y: 120, width: 1200, height: 800))
    }

    func testCrossScreenPolicyDoesNotOverrideUserResizeOrSameScreenMove() {
        let before = CGRect(x: 100, y: 100, width: 1200, height: 800)
        XCTAssertNil(WindowAccessor.framePreservingSizeAcrossScreens(
            currentFrame: CGRect(x: 200, y: 100, width: 900, height: 700), frameBeforeMove: before,
            previousScreenID: 1, currentScreenID: 1, isLiveResize: false, isFullScreen: false))
        XCTAssertNil(WindowAccessor.framePreservingSizeAcrossScreens(
            currentFrame: CGRect(x: 200, y: 100, width: 900, height: 700), frameBeforeMove: before,
            previousScreenID: 1, currentScreenID: 2, isLiveResize: true, isFullScreen: false))
        XCTAssertNil(WindowAccessor.framePreservingSizeAcrossScreens(
            currentFrame: CGRect(x: 200, y: 100, width: 900, height: 700), frameBeforeMove: before,
            previousScreenID: 1, currentScreenID: 2, isLiveResize: false, isFullScreen: true))
    }
}
