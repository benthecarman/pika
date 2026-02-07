import SwiftUI

struct NewChatView: View {
    let manager: AppManager
    @State private var npubInput = ""

    var body: some View {
        VStack(spacing: 12) {
            TextField("Peer npub", text: $npubInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier(TestIds.newChatPeerNpub)

            Button("Start Chat") {
                manager.dispatch(.createChat(peerNpub: npubInput.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(TestIds.newChatStart)

            Spacer()
        }
        .padding(16)
        .navigationTitle("New Chat")
    }
}
