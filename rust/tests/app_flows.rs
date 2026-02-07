use std::sync::{Arc, Mutex};
use std::time::Duration;

use pika_core::{AppAction, AppReconciler, AppUpdate, AuthState, FfiApp, Screen};
use tempfile::tempdir;

fn write_config(data_dir: &str, disable_network: bool) {
    let path = std::path::Path::new(data_dir).join("pika_config.json");
    let v = serde_json::json!({
        "disable_network": disable_network,
    });
    std::fs::write(path, serde_json::to_vec(&v).unwrap()).unwrap();
}

struct TestReconciler {
    updates: Arc<Mutex<Vec<AppUpdate>>>,
}

impl TestReconciler {
    fn new() -> (Self, Arc<Mutex<Vec<AppUpdate>>>) {
        let updates = Arc::new(Mutex::new(vec![]));
        (
            Self {
                updates: updates.clone(),
            },
            updates,
        )
    }
}

impl AppReconciler for TestReconciler {
    fn reconcile(&self, update: AppUpdate) {
        self.updates.lock().unwrap().push(update);
    }
}

#[test]
fn create_account_navigates_to_chat_list() {
    let dir = tempdir().unwrap();
    write_config(&dir.path().to_string_lossy(), true);
    let app = FfiApp::new(dir.path().to_string_lossy().to_string());
    let (reconciler, updates) = TestReconciler::new();
    app.listen_for_updates(Box::new(reconciler));

    assert_eq!(app.state().router.default_screen, Screen::Login);
    assert!(matches!(app.state().auth, AuthState::LoggedOut));

    app.dispatch(AppAction::CreateAccount);
    std::thread::sleep(Duration::from_millis(250));

    let s = app.state();
    assert!(matches!(s.auth, AuthState::LoggedIn { .. }));
    assert_eq!(s.router.default_screen, Screen::ChatList);

    let up = updates.lock().unwrap();
    assert!(!up.is_empty());
    // Revs must be strictly increasing by 1.
    for w in up.windows(2) {
        assert_eq!(w[0].rev() + 1, w[1].rev());
    }
}

#[test]
fn push_and_pop_stack_updates_router() {
    let dir = tempdir().unwrap();
    write_config(&dir.path().to_string_lossy(), true);
    let app = FfiApp::new(dir.path().to_string_lossy().to_string());
    app.dispatch(AppAction::CreateAccount);
    std::thread::sleep(Duration::from_millis(150));

    app.dispatch(AppAction::PushScreen {
        screen: Screen::NewChat,
    });
    std::thread::sleep(Duration::from_millis(30));
    assert_eq!(app.state().router.screen_stack, vec![Screen::NewChat]);

    // Native reports a pop.
    app.dispatch(AppAction::UpdateScreenStack { stack: vec![] });
    std::thread::sleep(Duration::from_millis(30));
    assert!(app.state().router.screen_stack.is_empty());
}

#[test]
fn send_message_creates_pending_then_sent() {
    let dir = tempdir().unwrap();
    write_config(&dir.path().to_string_lossy(), true);
    let app = FfiApp::new(dir.path().to_string_lossy().to_string());
    app.dispatch(AppAction::CreateAccount);
    std::thread::sleep(Duration::from_millis(200));

    let npub = match app.state().auth {
        AuthState::LoggedIn { ref npub, .. } => npub.clone(),
        _ => panic!("expected logged in"),
    };
    // Use "note to self" flow for deterministic offline tests.
    app.dispatch(AppAction::CreateChat { peer_npub: npub });
    std::thread::sleep(Duration::from_millis(120));

    let chat_id = app.state().chat_list[0].chat_id.clone();
    app.dispatch(AppAction::OpenChat {
        chat_id: chat_id.clone(),
    });
    std::thread::sleep(Duration::from_millis(40));

    app.dispatch(AppAction::SendMessage {
        chat_id,
        content: "hello".into(),
    });
    std::thread::sleep(Duration::from_millis(40));

    let s1 = app.state();
    let chat = s1.current_chat.unwrap();
    let msg = chat.messages.last().unwrap();
    assert_eq!(msg.content, "hello");
    assert!(
        matches!(msg.delivery, pika_core::MessageDeliveryState::Pending)
            || matches!(msg.delivery, pika_core::MessageDeliveryState::Sent)
    );

    std::thread::sleep(Duration::from_millis(120));
    let s2 = app.state();
    let chat2 = s2.current_chat.unwrap();
    let msg2 = chat2
        .messages
        .iter()
        .find(|m| m.content == "hello")
        .unwrap();
    assert!(matches!(
        msg2.delivery,
        pika_core::MessageDeliveryState::Sent
    ));
}

#[test]
fn logout_resets_state() {
    let dir = tempdir().unwrap();
    write_config(&dir.path().to_string_lossy(), true);
    let app = FfiApp::new(dir.path().to_string_lossy().to_string());
    app.dispatch(AppAction::CreateAccount);
    std::thread::sleep(Duration::from_millis(200));

    let npub = match app.state().auth {
        AuthState::LoggedIn { ref npub, .. } => npub.clone(),
        _ => panic!("expected logged in"),
    };
    app.dispatch(AppAction::CreateChat { peer_npub: npub });
    std::thread::sleep(Duration::from_millis(120));

    let chat_id = app.state().chat_list[0].chat_id.clone();
    app.dispatch(AppAction::OpenChat { chat_id });
    std::thread::sleep(Duration::from_millis(50));

    app.dispatch(AppAction::Logout);
    std::thread::sleep(Duration::from_millis(80));

    let s = app.state();
    assert!(matches!(s.auth, AuthState::LoggedOut));
    assert_eq!(s.router.default_screen, Screen::Login);
    assert!(s.chat_list.is_empty());
    assert!(s.current_chat.is_none());
}

#[test]
fn restore_session_recovers_chat_history() {
    let dir = tempdir().unwrap();
    let data_dir = dir.path().to_string_lossy().to_string();
    write_config(&data_dir, true);

    let app = FfiApp::new(data_dir.clone());
    let (reconciler, updates) = TestReconciler::new();
    app.listen_for_updates(Box::new(reconciler));
    app.dispatch(AppAction::CreateAccount);
    std::thread::sleep(Duration::from_millis(250));

    let my_npub = match app.state().auth {
        AuthState::LoggedIn { ref npub, .. } => npub.clone(),
        _ => panic!("expected logged in"),
    };
    app.dispatch(AppAction::CreateChat { peer_npub: my_npub });
    std::thread::sleep(Duration::from_millis(120));

    let chat_id = app.state().chat_list[0].chat_id.clone();
    app.dispatch(AppAction::SendMessage {
        chat_id: chat_id.clone(),
        content: "persist-me".into(),
    });
    std::thread::sleep(Duration::from_millis(160));

    // Grab the generated nsec from the update stream (spec-v2 requirement).
    let nsec = {
        let up = updates.lock().unwrap();
        let mut nsec: Option<String> = None;
        for u in up.iter() {
            if let AppUpdate::AccountCreated { nsec: s, .. } = u {
                nsec = Some(s.clone());
            }
        }
        nsec.expect("missing AccountCreated update with nsec")
    };

    // New process instance restores from the same encrypted per-identity DB.
    let app2 = FfiApp::new(data_dir);
    app2.dispatch(AppAction::RestoreSession { nsec });
    std::thread::sleep(Duration::from_millis(250));

    let s = app2.state();
    assert!(matches!(s.auth, AuthState::LoggedIn { .. }));
    assert!(!s.chat_list.is_empty());
    let summary = s.chat_list.iter().find(|c| c.chat_id == chat_id).unwrap();
    assert_eq!(summary.last_message.as_deref(), Some("persist-me"));

    app2.dispatch(AppAction::OpenChat { chat_id });
    std::thread::sleep(Duration::from_millis(120));
    let s2 = app2.state();
    let chat = s2.current_chat.unwrap();
    assert!(chat.messages.iter().any(|m| m.content == "persist-me"));
}

#[test]
fn paging_loads_older_messages_in_pages() {
    let dir = tempdir().unwrap();
    write_config(&dir.path().to_string_lossy(), true);
    let app = FfiApp::new(dir.path().to_string_lossy().to_string());
    app.dispatch(AppAction::CreateAccount);
    std::thread::sleep(Duration::from_millis(200));

    let npub = match app.state().auth {
        AuthState::LoggedIn { ref npub, .. } => npub.clone(),
        _ => panic!("expected logged in"),
    };
    app.dispatch(AppAction::CreateChat { peer_npub: npub });
    std::thread::sleep(Duration::from_millis(150));

    let chat_id = app.state().chat_list[0].chat_id.clone();

    // CreateChat pushes into the chat; pop back to chat list so initial open uses the default
    // newest-50 paging behavior.
    app.dispatch(AppAction::UpdateScreenStack { stack: vec![] });
    std::thread::sleep(Duration::from_millis(60));

    // Create > 50 messages while the chat is NOT open (so initial open loads newest 50).
    for i in 0..81 {
        app.dispatch(AppAction::SendMessage {
            chat_id: chat_id.clone(),
            content: format!("m{i}"),
        });
    }
    std::thread::sleep(Duration::from_millis(600));

    app.dispatch(AppAction::OpenChat {
        chat_id: chat_id.clone(),
    });
    std::thread::sleep(Duration::from_millis(200));

    let s = app.state();
    let chat = s.current_chat.unwrap();
    assert_eq!(chat.messages.len(), 50);
    assert!(chat.can_load_older);
    let oldest = chat.messages.first().unwrap().id.clone();

    // Load one page.
    app.dispatch(AppAction::LoadOlderMessages {
        chat_id: chat_id.clone(),
        before_message_id: oldest,
        limit: 30,
    });
    std::thread::sleep(Duration::from_millis(180));
    let s2 = app.state();
    let chat2 = s2.current_chat.unwrap();
    assert_eq!(chat2.messages.len(), 80);
    assert!(chat2.can_load_older);

    // Load last page.
    let oldest2 = chat2.messages.first().unwrap().id.clone();
    app.dispatch(AppAction::LoadOlderMessages {
        chat_id: chat_id.clone(),
        before_message_id: oldest2,
        limit: 30,
    });
    std::thread::sleep(Duration::from_millis(180));
    let s3 = app.state();
    let chat3 = s3.current_chat.unwrap();
    assert_eq!(chat3.messages.len(), 81);

    // One more load should now report no more history.
    let oldest3 = chat3.messages.first().unwrap().id.clone();
    app.dispatch(AppAction::LoadOlderMessages {
        chat_id,
        before_message_id: oldest3,
        limit: 30,
    });
    std::thread::sleep(Duration::from_millis(180));
    let s4 = app.state();
    let chat4 = s4.current_chat.unwrap();
    assert!(!chat4.can_load_older);
}
