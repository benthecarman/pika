import XCTest

final class PikaUITests: XCTestCase {
    func testCreateAccount_noteToSelf_sendMessage_and_logout() throws {
        let app = XCUIApplication()
        app.launch()

        // If we land on Login, create an account; otherwise we may have restored a prior session.
        let createAccount = app.buttons.matching(identifier: "login_create_account").firstMatch
        if createAccount.waitForExistence(timeout: 2) {
            createAccount.tap()
        }

        let chatsNavBar = app.navigationBars["Chats"]
        XCTAssertTrue(chatsNavBar.waitForExistence(timeout: 15))

        // Fetch our npub from the "My npub" alert (avoid clipboard access from UI tests).
        let myNpubBtn = app.buttons.matching(identifier: "chatlist_my_npub").firstMatch
        XCTAssertTrue(myNpubBtn.waitForExistence(timeout: 5))
        myNpubBtn.tap()

        let alert = app.alerts["My npub"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let npubValue = alert.staticTexts.matching(identifier: "chatlist_my_npub_value").firstMatch
        XCTAssertTrue(npubValue.waitForExistence(timeout: 5))
        let myNpub = npubValue.label
        XCTAssertTrue(myNpub.hasPrefix("npub1"), "Expected npub1..., got: \(myNpub)")

        // Close the alert.
        let close = alert.buttons["Close"]
        if close.exists { close.tap() }
        else { alert.buttons.element(boundBy: 0).tap() }

        // New chat.
        let newChat = app.buttons.matching(identifier: "chatlist_new_chat").firstMatch
        XCTAssertTrue(newChat.waitForExistence(timeout: 5))
        newChat.tap()

        let peerField = app.textFields.matching(identifier: "newchat_peer_npub").firstMatch
        XCTAssertTrue(peerField.waitForExistence(timeout: 5))
        peerField.tap()
        peerField.typeText(myNpub)

        let start = app.buttons.matching(identifier: "newchat_start").firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        // Send a message and ensure it appears.
        let msgField = app.textViews.matching(identifier: "chat_message_input").firstMatch
        let msgFieldFallback = app.textFields.matching(identifier: "chat_message_input").firstMatch
        let composer = msgField.exists ? msgField : msgFieldFallback
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        composer.tap()

        let msg = "hello from ios ui test"
        composer.typeText(msg)

        let send = app.buttons.matching(identifier: "chat_send").firstMatch
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        send.tap()

        // Bubble text may not be visible if the keyboard overlaps; existence is enough.
        XCTAssertTrue(app.staticTexts[msg].waitForExistence(timeout: 10))

        // Back to chat list and logout.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(chatsNavBar.waitForExistence(timeout: 10))

        let logout = app.buttons.matching(identifier: "chatlist_logout").firstMatch
        XCTAssertTrue(logout.waitForExistence(timeout: 5))
        logout.tap()

        XCTAssertTrue(app.staticTexts["Pika"].waitForExistence(timeout: 10))
    }
}

