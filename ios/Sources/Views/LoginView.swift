import SwiftUI

struct LoginView: View {
    let manager: AppManager
    @State private var nsecInput = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Pika")
                .font(.largeTitle.weight(.semibold))

            Button("Create Account") {
                manager.dispatch(.createAccount)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(TestIds.loginCreateAccount)

            Divider().padding(.vertical, 8)

            TextField("nsec (mock)", text: $nsecInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier(TestIds.loginNsecInput)

            Button("Login") {
                manager.login(nsec: nsecInput)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier(TestIds.loginSubmit)
        }
        .padding(20)
    }
}
