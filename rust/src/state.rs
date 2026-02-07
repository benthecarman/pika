use rand::RngCore;

#[derive(uniffi::Record, Clone, Debug)]
pub struct AppState {
    pub rev: u64,
    pub router: Router,
    pub auth: AuthState,
    pub chat_list: Vec<ChatSummary>,
    pub current_chat: Option<ChatViewState>,
    pub toast: Option<String>,
}

impl AppState {
    pub fn empty() -> Self {
        Self {
            rev: 0,
            router: Router {
                default_screen: Screen::Login,
                screen_stack: vec![],
            },
            auth: AuthState::LoggedOut,
            chat_list: vec![],
            current_chat: None,
            toast: None,
        }
    }
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct Router {
    pub default_screen: Screen,
    pub screen_stack: Vec<Screen>,
}

#[derive(uniffi::Enum, Clone, Debug, PartialEq)]
pub enum Screen {
    Login,
    ChatList,
    Chat { chat_id: String },
    NewChat,
}

#[derive(uniffi::Enum, Clone, Debug)]
pub enum AuthState {
    LoggedOut,
    LoggedIn { npub: String, pubkey: String },
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct ChatSummary {
    pub chat_id: String,
    pub peer_npub: String,
    pub peer_name: Option<String>,
    pub last_message: Option<String>,
    pub last_message_at: Option<i64>,
    pub unread_count: u32,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct ChatViewState {
    pub chat_id: String,
    pub peer_npub: String,
    pub peer_name: Option<String>,
    pub messages: Vec<ChatMessage>,
    pub can_load_older: bool,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct ChatMessage {
    pub id: String,
    pub sender_pubkey: String,
    pub content: String,
    pub timestamp: i64,
    pub is_mine: bool,
    pub delivery: MessageDeliveryState,
}

#[derive(uniffi::Enum, Clone, Debug)]
pub enum MessageDeliveryState {
    Pending,
    Sent,
    Failed { reason: String },
}

pub fn now_seconds() -> i64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64
}

pub fn generate_id(prefix: &str) -> String {
    let mut b = [0u8; 16];
    rand::thread_rng().fill_bytes(&mut b);
    format!("{prefix}_{}", hex::encode(b))
}

pub fn stable_hash(s: &str) -> String {
    use std::hash::{Hash, Hasher};
    let mut h = std::collections::hash_map::DefaultHasher::new();
    s.hash(&mut h);
    format!("{:016x}", h.finish())
}
