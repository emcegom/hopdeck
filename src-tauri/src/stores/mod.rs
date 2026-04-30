mod host_store;
mod settings_store;
mod vault_store;

use std::fs;
use std::path::PathBuf;

use chrono::Utc;
use directories::BaseDirs;
use serde::{Deserialize, Serialize};

use crate::errors::Result;
use crate::models::{AppSettings, HostDocument, VaultDocument};

pub use host_store::*;
pub use settings_store::*;
pub use vault_store::*;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ConfigBundle {
    pub version: u32,
    pub hosts: HostDocument,
    pub vault: VaultDocument,
    #[serde(default)]
    pub settings: AppSettings,
}

pub fn export_config_bundle_to_default() -> Result<String> {
    let bundle = ConfigBundle {
        version: 1,
        hosts: HostStore::default()?.load()?,
        vault: VaultStore::default()?.load()?,
        settings: SettingsStore::default()?.load()?,
    };
    let path = default_bundle_path()?;

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    fs::write(&path, serde_json::to_string_pretty(&bundle)?)?;
    Ok(path.to_string_lossy().to_string())
}

pub fn import_config_bundle_from_default() -> Result<HostDocument> {
    let path = default_bundle_path()?;
    let data = fs::read_to_string(path)?;
    let bundle: ConfigBundle = serde_json::from_str(&data)?;
    let validation_errors = bundle.hosts.validation_errors();
    if !validation_errors.is_empty() {
        return Err(crate::errors::HopdeckError::InvalidRequest(format!(
            "imported host document has {} validation error(s)",
            validation_errors.len()
        )));
    }

    write_bundle(&current_bundle()?, backup_before_import_path()?)?;
    let hosts = HostStore::default()?.replace_document(bundle.hosts)?;
    VaultStore::default()?.replace_document(bundle.vault)?;
    SettingsStore::default()?.replace(bundle.settings)?;
    Ok(hosts)
}

fn current_bundle() -> Result<ConfigBundle> {
    Ok(ConfigBundle {
        version: 1,
        hosts: HostStore::default()?.load()?,
        vault: VaultStore::default()?.load()?,
        settings: SettingsStore::default()?.load()?,
    })
}

fn write_bundle(bundle: &ConfigBundle, path: PathBuf) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    fs::write(path, serde_json::to_string_pretty(bundle)?)?;
    Ok(())
}

fn default_bundle_path() -> Result<PathBuf> {
    let dirs = BaseDirs::new().ok_or(crate::errors::HopdeckError::DataDirectoryUnavailable)?;
    Ok(dirs.home_dir().join(".hopdeck").join("hopdeck-backup.json"))
}

fn backup_before_import_path() -> Result<PathBuf> {
    let dirs = BaseDirs::new().ok_or(crate::errors::HopdeckError::DataDirectoryUnavailable)?;
    Ok(dirs.home_dir().join(".hopdeck").join(format!(
        "hopdeck-backup-before-import-{}.json",
        Utc::now().format("%Y%m%d%H%M%S")
    )))
}
