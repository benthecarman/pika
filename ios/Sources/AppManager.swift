import Foundation
import Observation

@MainActor
@Observable
final class AppManager: AppReconciler {
    let rust: FfiApp
    var state: AppState
    private var lastRevApplied: UInt64

    private let nsecStore = KeychainNsecStore()

    init() {
        let dataDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .path

        let rust = FfiApp(dataDir: dataDir)
        self.rust = rust

        let initial = rust.state()
        self.state = initial
        self.lastRevApplied = initial.rev

        rust.listenForUpdates(reconciler: self)

        if let nsec = nsecStore.getNsec(), !nsec.isEmpty {
            rust.dispatch(action: .restoreSession(nsec: nsec))
        }
    }

    nonisolated func reconcile(update: AppUpdate) {
        Task { @MainActor [weak self] in
            self?.apply(update: update)
        }
    }

    private func apply(update: AppUpdate) {
        let updateRev = update.rev
        if updateRev != lastRevApplied + 1 {
            #if DEBUG
            assertionFailure("Rev gap: expected \(lastRevApplied + 1), got \(updateRev)")
            #endif
            Task.detached(priority: .userInitiated) { [rust] in
                let snapshot = rust.state()
                await MainActor.run {
                    self.state = snapshot
                    self.lastRevApplied = snapshot.rev
                }
            }
            return
        }

        lastRevApplied = updateRev
        switch update {
        case .fullState(let s):
            state = s
        case .accountCreated(_, let nsec, _, _):
            // Required by spec-v2: native stores nsec; Rust never persists it.
            nsecStore.setNsec(nsec)
            state.rev = updateRev
        case .routerChanged(_, let router):
            state.router = router
            state.rev = updateRev
        case .authChanged(_, let auth):
            state.auth = auth
            state.rev = updateRev
        case .chatListChanged(_, let list):
            state.chatList = list
            state.rev = updateRev
        case .currentChatChanged(_, let chat):
            state.currentChat = chat
            state.rev = updateRev
        case .toastChanged(_, let toast):
            state.toast = toast
            state.rev = updateRev
        }
    }

    func dispatch(_ action: AppAction) {
        rust.dispatch(action: action)
    }

    func login(nsec: String) {
        if !nsec.isEmpty {
            nsecStore.setNsec(nsec)
        }
        dispatch(.login(nsec: nsec))
    }

    func logout() {
        nsecStore.clearNsec()
        dispatch(.logout)
    }

    func onForeground() {
        Task.detached(priority: .userInitiated) { [rust] in
            let snapshot = rust.state()
            await MainActor.run {
                self.state = snapshot
                self.lastRevApplied = snapshot.rev
            }
        }
    }
}

private extension AppUpdate {
    var rev: UInt64 {
        switch self {
        case .fullState(let s): return s.rev
        case .accountCreated(let rev, _, _, _): return rev
        case .routerChanged(let rev, _): return rev
        case .authChanged(let rev, _): return rev
        case .chatListChanged(let rev, _): return rev
        case .currentChatChanged(let rev, _): return rev
        case .toastChanged(let rev, _): return rev
        }
    }
}
