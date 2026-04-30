use std::fs;
use std::path::PathBuf;

use directories::BaseDirs;

use crate::errors::{HopdeckError, Result};
use crate::models::AppSettings;

#[derive(Debug, Clone)]
pub struct SettingsStore {
    path: PathBuf,
}

impl SettingsStore {
    pub fn default() -> Result<Self> {
        Ok(Self {
            path: default_settings_path()?,
        })
    }

    #[cfg(test)]
    pub fn with_path(path: PathBuf) -> Self {
        Self { path }
    }

    pub fn load(&self) -> Result<AppSettings> {
        if !self.path.exists() {
            let settings = AppSettings::default();
            self.save(&settings)?;
            return Ok(settings);
        }

        let data = fs::read_to_string(&self.path)?;
        if data.trim().is_empty() {
            let settings = AppSettings::default();
            self.save(&settings)?;
            return Ok(settings);
        }

        Ok(serde_json::from_str(&data)?)
    }

    pub fn replace(&self, settings: AppSettings) -> Result<AppSettings> {
        self.save(&settings)?;
        Ok(settings)
    }

    fn save(&self, settings: &AppSettings) -> Result<()> {
        if let Some(parent) = self.path.parent() {
            fs::create_dir_all(parent)?;
        }

        fs::write(&self.path, serde_json::to_string_pretty(settings)?)?;
        Ok(())
    }
}

fn default_settings_path() -> Result<PathBuf> {
    let dirs = BaseDirs::new().ok_or(HopdeckError::DataDirectoryUnavailable)?;
    Ok(dirs.home_dir().join(".hopdeck").join("settings.json"))
}

#[cfg(test)]
mod tests {
    use tempfile::tempdir;

    use super::*;

    #[test]
    fn round_trips_settings() {
        let dir = tempdir().unwrap();
        let store = SettingsStore::with_path(dir.path().join("settings.json"));
        let mut settings = AppSettings::default();
        settings.terminal.background_blur = 12;

        store.replace(settings.clone()).unwrap();

        assert_eq!(store.load().unwrap(), settings);
    }

    #[test]
    fn loads_legacy_partial_settings_with_defaults() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("settings.json");
        std::fs::write(
            &path,
            r#"{
  "version": 1,
  "terminal": {
    "fontSize": 15
  }
}"#,
        )
        .unwrap();
        let store = SettingsStore::with_path(path);

        let settings = store.load().unwrap();

        assert_eq!(settings.version, 1);
        assert_eq!(settings.terminal.font_size, 15);
        assert_eq!(settings.terminal.cursor_style, "block");
        assert_eq!(settings.vault.mode, "plain");
        assert!(settings.connection.auto_login);
    }
}
