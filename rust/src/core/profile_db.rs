use std::collections::HashMap;

use rusqlite::Connection;

use super::ProfileCache;

pub fn open_profile_db(data_dir: &str) -> Result<Connection, rusqlite::Error> {
    let path = std::path::Path::new(data_dir).join("profiles.sqlite3");
    let conn = Connection::open(path)?;
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS profiles (
            pubkey TEXT PRIMARY KEY,
            metadata JSONB,
            name TEXT,
            about TEXT,
            picture_url TEXT,
            event_created_at INTEGER NOT NULL DEFAULT 0
        );",
    )?;
    Ok(conn)
}

pub fn load_profiles(conn: &Connection) -> HashMap<String, ProfileCache> {
    let mut map = HashMap::new();
    let mut stmt = match conn
        .prepare("SELECT pubkey, name, about, picture_url, event_created_at FROM profiles")
    {
        Ok(s) => s,
        Err(e) => {
            tracing::warn!(%e, "failed to prepare profile load query");
            return map;
        }
    };
    let rows = match stmt.query_map([], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, Option<String>>(1)?,
            row.get::<_, Option<String>>(2)?,
            row.get::<_, Option<String>>(3)?,
            row.get::<_, i64>(4)?,
        ))
    }) {
        Ok(r) => r,
        Err(e) => {
            tracing::warn!(%e, "failed to query profiles from cache db");
            return map;
        }
    };
    for row in rows.flatten() {
        let (pubkey, name, about, picture_url, event_created_at) = row;
        map.insert(
            pubkey,
            ProfileCache {
                metadata_json: None,
                name,
                about,
                picture_url,
                event_created_at,
                last_checked_at: 0, // always re-check on app launch
            },
        );
    }
    map
}

/// Load the full metadata JSON for a single profile (used for profile editing).
pub fn load_metadata_json(conn: &Connection, pubkey: &str) -> Option<String> {
    conn.query_row(
        "SELECT json(metadata) FROM profiles WHERE pubkey = ?1",
        [pubkey],
        |row| row.get(0),
    )
    .ok()
}

pub fn save_profile(conn: &Connection, pubkey: &str, cache: &ProfileCache) {
    if let Err(e) = conn.execute(
        "INSERT INTO profiles (pubkey, metadata, name, about, picture_url, event_created_at)
         VALUES (?1, jsonb(?2), ?3, ?4, ?5, ?6)
         ON CONFLICT(pubkey) DO UPDATE SET
            metadata = jsonb(excluded.metadata),
            name = excluded.name,
            about = excluded.about,
            picture_url = excluded.picture_url,
            event_created_at = excluded.event_created_at",
        rusqlite::params![
            pubkey,
            cache.metadata_json,
            cache.name,
            cache.about,
            cache.picture_url,
            cache.event_created_at,
        ],
    ) {
        tracing::warn!(%e, pubkey, "failed to save profile to cache db");
    }
}

/// Delete all cached profiles (used on logout).
pub fn clear_all(conn: &Connection) {
    if let Err(e) = conn.execute_batch("DELETE FROM profiles;") {
        tracing::warn!(%e, "failed to clear profile cache db");
    }
}
