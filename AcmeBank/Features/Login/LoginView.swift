import SwiftUI

/// Login screen for AcmeBank.
///
/// Renders the branding header, username / password fields, and a
/// primary Sign In button.  All business logic lives in `LoginViewModel`;
/// this view is a pure projection of that state.
///
/// `ThemeToggleButton` is placed in the branding strip so the user can
/// switch colour scheme before and after signing in without leaving the
/// screen.  The button reads `ThemeStore` from the environment (injected
/// by `AcmeBankApp`).
struct LoginView: View {

    @ObservedObject var viewModel: LoginViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                brandingHeader
                credentialFields
                signInButton
                errorBanner
            }
            .padding(.horizontal, 24)
            .padding(.top, 64)
        }
        .background(Color(.systemBackground))
    }

    // MARK: – Sub-views

    private var brandingHeader: some View {
        VStack(spacing: 8) {
            // Branding strip: icon + theme toggle aligned trailing
            HStack(alignment: .center) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color("BrandNavy"))
                    .accessibilityHidden(true)

                Spacer()

                ThemeToggleButton()
                    .foregroundStyle(Color("BrandNavy"))
            }

            Text("Acme Bank")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(Color.primary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(LoginAccessibility.brandingHeader)

            Text("Sign in to your account")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)

            Text("Secured by Okta")
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
    }

    private var credentialFields: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Username")
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.secondary)

                TextField("Enter your username", text: $viewModel.username)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("Username")
                    .accessibilityIdentifier(LoginAccessibility.usernameField)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.secondary)

                SecureField("Enter your password", text: $viewModel.password)
                    .textContentType(.password)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("Password")
                    .accessibilityIdentifier(LoginAccessibility.passwordField)
            }
        }
    }

    private var signInButton: some View {
        Button {
            viewModel.submitSignIn()
        } label: {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(Color.white)
                } else {
                    Text("Sign In")
                        .font(.body)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .tint(Color("BrandNavy"))
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isLoading)
        .accessibilityLabel("Sign In")
        .accessibilityIdentifier(LoginAccessibility.signInButton)
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let message = viewModel.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityIdentifier(LoginAccessibility.errorLabel)
        }
    }
}

// MARK: – Preview

#Preview {
    LoginView(viewModel: LoginViewModel())
        .environmentObject(ThemeStore())
}
