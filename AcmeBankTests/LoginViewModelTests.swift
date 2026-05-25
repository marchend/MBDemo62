import XCTest
@testable import AcmeBank

final class LoginViewModelTests: XCTestCase {

    // MARK: – Initial state

    func testInitialState() {
        let vm = LoginViewModel()

        XCTAssertEqual(vm.username, "", "username should start empty")
        XCTAssertEqual(vm.password, "", "password should start empty")
        XCTAssertFalse(vm.isLoading, "isLoading should start false")
        XCTAssertNil(vm.errorMessage, "errorMessage should start nil")
    }

    // MARK: – submitSignIn

    func testSubmitSignIn_callsStub() async {
        var wasCalled = false
        let vm = LoginViewModel(signIn: { wasCalled = true })

        await vm.submitSignIn()

        XCTAssertTrue(wasCalled, "submitSignIn() should invoke the injected signIn closure")
    }

    func testSubmitSignIn_setsIsLoading() async {
        let vm = LoginViewModel()

        await vm.submitSignIn()

        XCTAssertTrue(vm.isLoading, "isLoading should be true after submitSignIn()")
    }

    // MARK: – State mutation helpers

    func testUsernameBinding_updatesPublishedValue() {
        let vm = LoginViewModel()
        vm.username = "alice@example.com"

        XCTAssertEqual(vm.username, "alice@example.com")
    }

    func testPasswordBinding_updatesPublishedValue() {
        let vm = LoginViewModel()
        vm.password = "s3cr3t"

        XCTAssertEqual(vm.password, "s3cr3t")
    }

    func testErrorMessage_canBeSet() {
        let vm = LoginViewModel()
        vm.errorMessage = "Invalid credentials"

        XCTAssertEqual(vm.errorMessage, "Invalid credentials")
    }
}
