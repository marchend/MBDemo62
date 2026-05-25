import SwiftUI

@main
struct AcmeBankApp: App {
    var body: some Scene {
        WindowGroup {
            LoginView(viewModel: LoginViewModel())
        }
    }
}
