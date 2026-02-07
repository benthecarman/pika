import SwiftUI

struct ContentView: View {
    @Bindable var manager: AppManager
    @State private var showToastAlert = false

    var body: some View {
        let router = manager.state.router
        switch router.defaultScreen {
        case .login:
            LoginView(manager: manager)
        default:
            NavigationStack(path: $manager.state.router.screenStack) {
                screenView(manager: manager, screen: router.defaultScreen)
                    .navigationDestination(for: Screen.self) { screen in
                        screenView(manager: manager, screen: screen)
                    }
            }
            .onChange(of: manager.state.router.screenStack) { old, new in
                // Only report platform-initiated pops.
                if new.count < old.count {
                    manager.dispatch(.updateScreenStack(stack: new))
                }
            }
            .onChange(of: manager.state.toast) { _, new in
                showToastAlert = (new != nil)
            }
            .alert("Pika", isPresented: $showToastAlert) {
                Button("OK") { manager.dispatch(.clearToast) }
            } message: {
                Text(manager.state.toast ?? "")
            }
        }
    }
}

@ViewBuilder
private func screenView(manager: AppManager, screen: Screen) -> some View {
    switch screen {
    case .login:
        LoginView(manager: manager)
    case .chatList:
        ChatListView(manager: manager)
    case .newChat:
        NewChatView(manager: manager)
    case .chat:
        ChatView(manager: manager)
    }
}
