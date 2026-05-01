use std::fs;
use std::path::PathBuf;

use directories::BaseDirs;
use plist::{Dictionary, Value};

use crate::errors::{HopdeckError, Result};
use crate::models::{AppSettings, TerminalColors};

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

    pub fn import_iterm2_theme(&self) -> Result<AppSettings> {
        let mut settings = self.load()?;
        let preferences = load_iterm2_preferences()?;
        apply_iterm2_theme_to_settings(&mut settings, &preferences)?;
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

fn load_iterm2_preferences() -> Result<Value> {
    let dirs = BaseDirs::new().ok_or(HopdeckError::DataDirectoryUnavailable)?;
    let path = dirs
        .home_dir()
        .join("Library")
        .join("Preferences")
        .join("com.googlecode.iterm2.plist");

    if !path.exists() {
        return Err(HopdeckError::InvalidRequest(
            "iTerm2 preferences were not found at ~/Library/Preferences/com.googlecode.iterm2.plist".to_string(),
        ));
    }

    Value::from_file(&path).map_err(|error| {
        HopdeckError::InvalidRequest(format!("unable to read iTerm2 preferences: {error}"))
    })
}

fn apply_iterm2_theme_to_settings(settings: &mut AppSettings, preferences: &Value) -> Result<()> {
    let profile = select_iterm2_profile(preferences).ok_or_else(|| {
        HopdeckError::InvalidRequest("unable to find an iTerm2 profile in preferences".to_string())
    })?;

    if let Some(background) = color_from_profile(profile, "Background Color") {
        settings.terminal.colors.background = background;
    }
    if let Some(foreground) = color_from_profile(profile, "Foreground Color") {
        settings.terminal.colors.foreground = foreground;
    }
    if let Some(cursor) = color_from_profile(profile, "Cursor Color") {
        settings.terminal.colors.cursor = cursor;
    }
    if let Some(selection) = color_from_profile(profile, "Selection Color") {
        settings.terminal.colors.selection = selection;
    }

    let ansi: Vec<String> = (0..16)
        .filter_map(|index| color_from_profile(profile, &format!("Ansi {index} Color")))
        .collect();
    if ansi.len() == 16 {
        settings.terminal.colors.ansi = ansi;
    } else if settings.terminal.colors.ansi.len() != 16 {
        settings.terminal.colors.ansi = TerminalColors::default().ansi;
    }

    if let Some(transparency) = profile.get("Transparency").and_then(number_from_value) {
        let opacity = ((1.0 - transparency.clamp(0.0, 1.0)) * 100.0).round();
        settings.terminal.background_opacity = opacity.clamp(15.0, 100.0) as u8;
    }

    if profile
        .get("Blur")
        .and_then(Value::as_boolean)
        .unwrap_or(false)
    {
        if let Some(radius) = profile.get("Blur Radius").and_then(number_from_value) {
            settings.terminal.background_blur = radius.round().clamp(0.0, 32.0) as u16;
        }
    } else {
        settings.terminal.background_blur = 0;
    }

    if let Some((font_family, font_size)) = profile
        .get("Normal Font")
        .and_then(Value::as_string)
        .and_then(parse_iterm2_font)
    {
        settings.terminal.font_family = font_family;
        settings.terminal.font_size = font_size;
    }

    Ok(())
}

fn select_iterm2_profile(preferences: &Value) -> Option<&Dictionary> {
    let root = preferences.as_dictionary()?;
    let profiles = root.get("New Bookmarks")?.as_array()?;
    let default_guid = root.get("Default Bookmark Guid").and_then(Value::as_string);

    if let Some(default_guid) = default_guid {
        if let Some(profile) = profiles
            .iter()
            .filter_map(Value::as_dictionary)
            .find(|profile| {
                profile
                    .get("Guid")
                    .and_then(Value::as_string)
                    .is_some_and(|guid| guid == default_guid)
            })
        {
            return Some(profile);
        }
    }

    profiles
        .iter()
        .filter_map(Value::as_dictionary)
        .find(|profile| {
            profile
                .get("Default Bookmark")
                .and_then(Value::as_boolean)
                .unwrap_or(false)
        })
        .or_else(|| profiles.first().and_then(Value::as_dictionary))
}

fn color_from_profile(profile: &Dictionary, base_key: &str) -> Option<String> {
    let dark_key = format!("{base_key} (Dark)");
    profile
        .get(&dark_key)
        .or_else(|| profile.get(base_key))
        .and_then(color_to_hex)
}

fn color_to_hex(value: &Value) -> Option<String> {
    let color = value.as_dictionary()?;
    let red = color
        .get("Red Component")
        .and_then(number_from_value)?
        .clamp(0.0, 1.0);
    let green = color
        .get("Green Component")
        .and_then(number_from_value)?
        .clamp(0.0, 1.0);
    let blue = color
        .get("Blue Component")
        .and_then(number_from_value)?
        .clamp(0.0, 1.0);

    Some(format!(
        "#{:02X}{:02X}{:02X}",
        (red * 255.0).round() as u8,
        (green * 255.0).round() as u8,
        (blue * 255.0).round() as u8
    ))
}

fn number_from_value(value: &Value) -> Option<f64> {
    value
        .as_real()
        .or_else(|| value.as_signed_integer().map(|number| number as f64))
        .or_else(|| value.as_unsigned_integer().map(|number| number as f64))
        .or_else(|| {
            value
                .as_string()
                .and_then(|number| number.parse::<f64>().ok())
        })
}

fn parse_iterm2_font(font: &str) -> Option<(String, u16)> {
    let (family, size) = font.trim().rsplit_once(' ')?;
    let family = family.trim();
    if family.is_empty() {
        return None;
    }

    let size = size.parse::<f64>().ok()?.round().clamp(8.0, 40.0) as u16;
    let escaped_family = family.replace('"', "\\\"");
    Some((
        format!(
            "\"{escaped_family}\", \"SFMono-Regular\", Consolas, \"Liberation Mono\", monospace"
        ),
        size,
    ))
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
        assert_eq!(settings.terminal.background_opacity, 100);
        assert_eq!(settings.terminal.colors.ansi.len(), 16);
        assert_eq!(settings.vault.mode, "plain");
        assert!(settings.connection.auto_login);
    }

    #[test]
    fn imports_iterm2_default_profile_theme() {
        let mut settings = AppSettings::default();
        let preferences = Value::Dictionary(Dictionary::from_iter([
            (
                "Default Bookmark Guid".to_string(),
                Value::String("profile-2".to_string()),
            ),
            (
                "New Bookmarks".to_string(),
                Value::Array(vec![
                    Value::Dictionary(Dictionary::from_iter([(
                        "Guid".to_string(),
                        Value::String("profile-1".to_string()),
                    )])),
                    Value::Dictionary(sample_iterm2_profile("profile-2")),
                ]),
            ),
        ]));

        apply_iterm2_theme_to_settings(&mut settings, &preferences).unwrap();

        assert_eq!(settings.terminal.colors.background, "#001E27");
        assert_eq!(settings.terminal.colors.foreground, "#9CC2C3");
        assert_eq!(settings.terminal.colors.cursor, "#F34B00");
        assert_eq!(settings.terminal.colors.selection, "#003748");
        assert_eq!(settings.terminal.colors.ansi[1], "#FF0000");
        assert_eq!(settings.terminal.background_opacity, 80);
        assert_eq!(settings.terminal.background_blur, 15);
        assert_eq!(
            settings.terminal.font_family,
            "\"MesloLGS-NF-Regular\", \"SFMono-Regular\", Consolas, \"Liberation Mono\", monospace"
        );
        assert_eq!(settings.terminal.font_size, 14);
    }

    fn sample_iterm2_profile(guid: &str) -> Dictionary {
        let mut profile = Dictionary::new();
        profile.insert("Guid".to_string(), Value::String(guid.to_string()));
        profile.insert(
            "Normal Font".to_string(),
            Value::String("MesloLGS-NF-Regular 14".to_string()),
        );
        profile.insert("Transparency".to_string(), Value::Real(0.1952563976774142));
        profile.insert("Blur".to_string(), Value::Boolean(true));
        profile.insert("Blur Radius".to_string(), Value::Real(14.83252918956044));
        profile.insert(
            "Background Color (Dark)".to_string(),
            color_value(0.0, 0.1178361028432846, 0.1517027318477631),
        );
        profile.insert(
            "Foreground Color (Dark)".to_string(),
            color_value(0.6100099086761475, 0.7592126131057739, 0.7630731463432312),
        );
        profile.insert(
            "Cursor Color (Dark)".to_string(),
            color_value(0.9547511339187622, 0.2933464646339417, 0.0),
        );
        profile.insert(
            "Selection Color (Dark)".to_string(),
            color_value(0.0, 0.2157628536224365, 0.2816705107688904),
        );

        for index in 0..16 {
            profile.insert(
                format!("Ansi {index} Color (Dark)"),
                if index == 1 {
                    color_value(1.0, 0.0, 0.0)
                } else {
                    color_value(0.0, 0.0, 0.0)
                },
            );
        }

        profile
    }

    fn color_value(red: f64, green: f64, blue: f64) -> Value {
        Value::Dictionary(Dictionary::from_iter([
            ("Red Component".to_string(), Value::Real(red)),
            ("Green Component".to_string(), Value::Real(green)),
            ("Blue Component".to_string(), Value::Real(blue)),
        ]))
    }
}
