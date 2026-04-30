use std::fs;
use std::path::PathBuf;

use directories::BaseDirs;

use crate::errors::{HopdeckError, Result};
use crate::models::{HostAuth, HostDocument, VaultDocument, VaultItem};

#[derive(Debug, Clone)]
pub struct VaultStore {
    path: PathBuf,
}

impl VaultStore {
    pub fn default() -> Result<Self> {
        Ok(Self {
            path: default_vault_path()?,
        })
    }

    #[cfg(test)]
    pub fn with_path(path: PathBuf) -> Self {
        Self { path }
    }

    pub fn load(&self) -> Result<VaultDocument> {
        if !self.path.exists() {
            let document = VaultDocument::default();
            self.save(&document)?;
            return Ok(document);
        }

        let data = fs::read_to_string(&self.path)?;
        if data.trim().is_empty() {
            let document = VaultDocument::default();
            self.save(&document)?;
            return Ok(document);
        }

        Ok(serde_json::from_str(&data)?)
    }

    pub fn replace_document(&self, document: VaultDocument) -> Result<VaultDocument> {
        self.save(&document)?;
        Ok(document)
    }

    pub fn save_password(
        &self,
        password_ref: String,
        username: String,
        password: String,
    ) -> Result<VaultDocument> {
        let mut document = self.load()?;
        let password_ref = password_ref.trim();

        if password_ref.is_empty() {
            return Err(HopdeckError::InvalidRequest(
                "password ref is required".to_string(),
            ));
        }

        document
            .items
            .insert(password_ref.to_string(), VaultItem { username, password });
        self.save(&document)?;
        Ok(document)
    }

    pub fn delete_password(&self, password_ref: String) -> Result<VaultDocument> {
        let mut document = self.load()?;
        document.items.remove(&password_ref);
        self.save(&document)?;
        Ok(document)
    }

    pub fn get_password_for_host(
        &self,
        hosts: &HostDocument,
        host_id: &str,
    ) -> Result<Option<String>> {
        let host = hosts
            .hosts
            .get(host_id)
            .ok_or_else(|| HopdeckError::HostNotFound(host_id.to_string()))?;
        let HostAuth::Password {
            password_ref: Some(password_ref),
            ..
        } = &host.auth
        else {
            return Ok(None);
        };

        Ok(self
            .load()?
            .items
            .get(password_ref)
            .map(|item| item.password.clone()))
    }

    pub fn password_for_ref(&self, password_ref: &str) -> Result<Option<String>> {
        Ok(self
            .load()?
            .items
            .get(password_ref)
            .map(|item| item.password.clone()))
    }

    fn save(&self, document: &VaultDocument) -> Result<()> {
        if let Some(parent) = self.path.parent() {
            fs::create_dir_all(parent)?;
        }

        fs::write(&self.path, serde_json::to_string_pretty(document)?)?;
        Ok(())
    }
}

fn default_vault_path() -> Result<PathBuf> {
    let dirs = BaseDirs::new().ok_or(HopdeckError::DataDirectoryUnavailable)?;
    Ok(dirs.home_dir().join(".hopdeck").join("vault.json"))
}

#[cfg(test)]
mod tests {
    use tempfile::tempdir;

    use crate::models::{Host, HostAuth, HostDocument};

    use super::*;

    #[test]
    fn round_trips_plain_vault_document() {
        let dir = tempdir().unwrap();
        let store = VaultStore::with_path(dir.path().join("vault.json"));

        let saved = store
            .save_password(
                "password:prod".to_string(),
                "root".to_string(),
                "secret".to_string(),
            )
            .unwrap();

        assert_eq!(saved.items["password:prod"].password, "secret");
        assert_eq!(store.load().unwrap(), saved);
    }

    #[test]
    fn deletes_password_entries() {
        let dir = tempdir().unwrap();
        let store = VaultStore::with_path(dir.path().join("vault.json"));

        store
            .save_password(
                "password:prod".to_string(),
                "root".to_string(),
                "secret".to_string(),
            )
            .unwrap();
        let document = store.delete_password("password:prod".to_string()).unwrap();

        assert!(!document.items.contains_key("password:prod"));
    }

    #[test]
    fn resolves_password_for_host_ref() {
        let dir = tempdir().unwrap();
        let store = VaultStore::with_path(dir.path().join("vault.json"));
        store
            .save_password(
                "password:prod".to_string(),
                "app".to_string(),
                "secret".to_string(),
            )
            .unwrap();

        let mut hosts = HostDocument::default();
        hosts.hosts.insert(
            "prod".to_string(),
            Host {
                id: "prod".to_string(),
                alias: "prod".to_string(),
                host: "example.com".to_string(),
                user: "app".to_string(),
                port: 22,
                tags: Vec::new(),
                favorite: false,
                is_jump_host: false,
                jump_chain: Vec::new(),
                auth: HostAuth::Password {
                    password_ref: Some("password:prod".to_string()),
                    auto_login: true,
                },
                notes: String::new(),
                created_at: None,
                updated_at: None,
                last_connected_at: None,
            },
        );

        assert_eq!(
            store.get_password_for_host(&hosts, "prod").unwrap(),
            Some("secret".to_string())
        );
    }
}
