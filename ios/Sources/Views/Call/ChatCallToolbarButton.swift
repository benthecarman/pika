import SwiftUI

@MainActor
struct ChatCallToolbarButton: View {
    let callForChat: CallState?
    let hasLiveCallElsewhere: Bool
    let onStartCall: @MainActor () -> Void
    let onStartVideoCall: @MainActor () -> Void
    let onOpenCallScreen: @MainActor () -> Void

    @State private var showMicDeniedAlert = false

    private var hasLiveCallForChat: Bool {
        callForChat?.isLive ?? false
    }

    private var isDisabled: Bool {
        !hasLiveCallForChat && hasLiveCallElsewhere
    }

    private var symbolName: String {
        hasLiveCallForChat ? "phone.fill" : "phone"
    }

    var body: some View {
        if hasLiveCallForChat {
            Button {
                onOpenCallScreen()
            } label: {
                Image(systemName: symbolName)
                    .font(.body.weight(.semibold))
            }
            .accessibilityIdentifier(TestIds.chatCallOpen)
        } else {
            Menu {
                Button {
                    startMicPermissionAction {
                        onStartCall()
                        onOpenCallScreen()
                    }
                } label: {
                    Label("Audio Call", systemImage: "phone.fill")
                }

                Button {
                    startMicAndCameraPermissionAction {
                        onStartVideoCall()
                        onOpenCallScreen()
                    }
                } label: {
                    Label("Video Call", systemImage: "video.fill")
                }
            } label: {
                Image(systemName: symbolName)
                    .font(.body.weight(.semibold))
            }
            .disabled(isDisabled)
            .accessibilityIdentifier(TestIds.chatCallStart)
            .alert("Permission Needed", isPresented: $showMicDeniedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Microphone and camera permissions are required for calls.")
            }
        }
    }

    private func startMicPermissionAction(_ action: @escaping @MainActor () -> Void) {
        CallPermissionActions.withMicPermission(onDenied: { showMicDeniedAlert = true }, action: action)
    }

    private func startMicAndCameraPermissionAction(_ action: @escaping @MainActor () -> Void) {
        CallPermissionActions.withMicAndCameraPermission(onDenied: { showMicDeniedAlert = true }, action: action)
    }
}
