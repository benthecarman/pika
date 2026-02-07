use std::path::{Path, PathBuf};
use std::sync::OnceLock;

use anyhow::{anyhow, Context, Result};
use mdk_core::{MdkConfig, MDK};
use mdk_sqlite_storage::MdkSqliteStorage;
use nostr_sdk::prelude::PublicKey;

pub type PikaMdk = MDK<MdkSqliteStorage>;

// Keep stable IDs; spec-v2 uses a reverse-DNS identifier.
pub const SERVICE_ID: &str = "com.pika.app";

pub fn mdk_db_path(data_dir: &str, pubkey_hex: &str) -> PathBuf {
    Path::new(data_dir)
        .join("mls")
        .join(pubkey_hex)
        .join("mdk.sqlite3")
}

pub fn db_key_id(pubkey_hex: &str) -> String {
    format!("mdk.db.key.{pubkey_hex}")
}

pub fn init_keyring_once() -> Result<()> {
    static INIT: OnceLock<std::result::Result<(), String>> = OnceLock::new();
    match INIT.get_or_init(|| init_keyring_inner().map_err(|e| e.to_string())) {
        Ok(()) => Ok(()),
        Err(e) => Err(anyhow!(e.clone())),
    }
}

fn init_keyring_inner() -> Result<()> {
    // IMPORTANT: `set_default_store` can only be called once per process.
    // We guard it via `OnceLock` above.
    #[cfg(target_os = "ios")]
    {
        let store = apple_native_keyring_store::protected::Store::new()
            .context("failed to create Apple protected keyring store")?;
        keyring_core::set_default_store(store);
        return Ok(());
    }

    #[cfg(target_os = "android")]
    {
        use android_native_keyring_store::credential::AndroidStore;

        // Prefer ndk-context if available. If the host app uses the Kotlin/JNI init hook,
        // this should be a no-op because the store is already set; however `set_default_store`
        // can only be called once, so we avoid calling it again here.
        //
        // We can't reliably detect whether a store is already set, so this path should only
        // be used when we can set it ourselves.
        let store = AndroidStore::from_ndk_context()
            .context("Android keyring store not initialized. Call Keyring.setAndroidKeyringCredentialBuilder(context) early in MainActivity, or use a framework that provides ndk-context.")?;
        keyring_core::set_default_store(store);
        return Ok(());
    }

    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    {
        // Desktop/dev fallback: keep encrypted storage working for local iteration.
        keyring_core::set_default_store(
            keyring_core::mock::Store::new().context("failed to create mock keyring store")?,
        );
        Ok(())
    }
}

pub fn open_mdk(data_dir: &str, pubkey: &PublicKey) -> Result<PikaMdk> {
    init_keyring_once()?;

    let pubkey_hex = pubkey.to_hex();
    let db_path = mdk_db_path(data_dir, &pubkey_hex);
    if let Some(parent) = db_path.parent() {
        std::fs::create_dir_all(parent)
            .with_context(|| format!("create mdk db dir: {}", parent.display()))?;
    }

    let storage = MdkSqliteStorage::new(&db_path, SERVICE_ID, &db_key_id(&pubkey_hex))
        .with_context(|| format!("open encrypted mdk sqlite db: {}", db_path.display()))?;

    Ok(MDK::builder(storage)
        .with_config(MdkConfig::default())
        .build())
}
