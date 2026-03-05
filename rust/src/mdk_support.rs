use std::path::{Path, PathBuf};
use std::sync::OnceLock;

use anyhow::{anyhow, Context, Result};
use mdk_core::{MdkConfig, MDK};
use mdk_sqlite_storage::MdkSqliteStorage;
use nostr_sdk::prelude::PublicKey;

pub type PikaMdk = MDK<MdkSqliteStorage>;

// Keep stable IDs; spec-v2 uses a reverse-DNS identifier.
pub const SERVICE_ID: &str = "com.pika.app";

pub fn init_keyring_once(#[allow(unused)] keychain_group: &str) -> Result<()> {
    static INIT: OnceLock<std::result::Result<(), String>> = OnceLock::new();
    match INIT.get_or_init(|| init_keyring_inner(keychain_group).map_err(|e| e.to_string())) {
        Ok(()) => Ok(()),
        Err(e) => Err(anyhow!(e.clone())),
    }
}

fn init_keyring_inner(#[allow(unused)] keychain_group: &str) -> Result<()> {
    #[cfg(target_os = "ios")]
    {
        let mut config = std::collections::HashMap::new();
        config.insert("access-group", keychain_group);
        let store = apple_native_keyring_store::protected::Store::new_with_configuration(&config)
            .context(
            "failed to create Apple protected keyring store with shared access group",
        )?;
        keyring_core::set_default_store(store);
        return Ok(());
    }

    #[cfg(target_os = "android")]
    {
        use android_native_keyring_store::credential::AndroidStore;
        let store =
            AndroidStore::from_ndk_context().context("Android keyring store not initialized.")?;
        keyring_core::set_default_store(store);
        return Ok(());
    }

    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    {
        keyring_core::set_default_store(
            keyring_core::mock::Store::new().context("failed to create mock keyring store")?,
        );
        Ok(())
    }
}

pub fn mdk_db_path(data_dir: &str, pubkey_hex: &str) -> PathBuf {
    Path::new(data_dir)
        .join("mls")
        .join(pubkey_hex)
        .join("mdk.sqlite3")
}

pub fn open_mdk(data_dir: &str, pubkey: &PublicKey, _keychain_group: &str) -> Result<PikaMdk> {
    let pubkey_hex = pubkey.to_hex();
    let db_path = mdk_db_path(data_dir, &pubkey_hex);
    if let Some(parent) = db_path.parent() {
        std::fs::create_dir_all(parent)
            .with_context(|| format!("create mdk db dir: {}", parent.display()))?;
    }

    let storage = MdkSqliteStorage::new_unencrypted(&db_path)
        .with_context(|| format!("open mdk sqlite db: {}", db_path.display()))?;

    Ok(MDK::builder(storage).with_config(mdk_config()).build())
}

fn mdk_config() -> MdkConfig {
    MdkConfig {
        ..Default::default()
    }
}
