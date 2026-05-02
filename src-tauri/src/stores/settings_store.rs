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

    if let Some(cursor_style) = profile
        .get("Cursor Type")
        .and_then(number_from_value)
        .and_then(cursor_style_from_iterm2_type)
    {
        settings.terminal.cursor_style = cursor_style.to_string();
    }

    if let Some(use_bold_font) = profile.get("Use Bold Font").and_then(Value::as_boolean) {
        settings.terminal.font_weight_bold = if use_bold_font { "700" } else { "400" }.to_string();
    }

    if let Some(draw_bold_bright) = bool_from_first_profile_key(
        profile,
        &[
            "Draw Bold Text In Bright Colors",
            "Draw Bold Text in Bright Colors",
            "Bold Text in Bright Colors",
            "Brighten Bold Text",
        ],
    ) {
        settings.terminal.draw_bold_text_in_bright_colors = draw_bold_bright;
    }

    if let Some(minimum_contrast_ratio) = number_from_first_profile_key(
        profile,
        &[
            "Minimum Contrast Ratio",
            "Minimum Contrast",
            "Minimum Contrast Ratio Value",
        ],
    )
    .and_then(minimum_contrast_ratio_from_iterm2)
    {
        settings.terminal.minimum_contrast_ratio = minimum_contrast_ratio;
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

fn bool_from_first_profile_key(profile: &Dictionary, keys: &[&str]) -> Option<bool> {
    keys.iter()
        .find_map(|key| profile.get(*key).and_then(Value::as_boolean))
}

fn number_from_first_profile_key(profile: &Dictionary, keys: &[&str]) -> Option<f64> {
    keys.iter()
        .find_map(|key| profile.get(*key).and_then(number_from_value))
}

fn cursor_style_from_iterm2_type(cursor_type: f64) -> Option<&'static str> {
    match cursor_type.round() as i64 {
        0 => Some("block"),
        1 => Some("bar"),
        2 => Some("underline"),
        _ => None,
    }
}

fn minimum_contrast_ratio_from_iterm2(value: f64) -> Option<f64> {
    if !value.is_finite() {
        return None;
    }

    let ratio = if (0.0..=1.0).contains(&value) {
        1.0 + (value * 20.0)
    } else {
        value
    };

    Some(round_to_tenth(ratio.clamp(1.0, 21.0)))
}

fn round_to_tenth(value: f64) -> f64 {
    (value * 10.0).round() / 10.0
}

fn parse_iterm2_font(font: &str) -> Option<(String, u16)> {
    let (postscript_name, size) = font.trim().rsplit_once(' ')?;
    let postscript_name = postscript_name.trim();
    if postscript_name.is_empty() {
        return None;
    }

    let size = size.parse::<f64>().ok()?.round().clamp(8.0, 40.0) as u16;
    let mut families = Vec::new();
    push_font_family(&mut families, postscript_name.to_string());

    if let Some(family_name) = family_name_from_postscript_name(postscript_name) {
        push_font_family(&mut families, family_name);
    }

    push_font_family(&mut families, "SFMono-Regular".to_string());
    push_font_family(&mut families, "Menlo".to_string());
    push_font_family(&mut families, "monospace".to_string());

    Some((families.join(", "), size))
}

fn push_font_family(families: &mut Vec<String>, family: String) {
    let css_family = css_font_family(&family);
    if !families.iter().any(|existing| existing == &css_family) {
        families.push(css_family);
    }
}

fn css_font_family(family: &str) -> String {
    if family.eq_ignore_ascii_case("monospace") {
        return "monospace".to_string();
    }

    format!("\"{}\"", family.replace('"', "\\\""))
}

fn family_name_from_postscript_name(postscript_name: &str) -> Option<String> {
    let base = strip_font_style_suffix(postscript_name);
    if base == postscript_name {
        return None;
    }

    let family = base.replace('-', " ");
    let family = family.trim();
    (!family.is_empty()).then(|| family.to_string())
}

fn strip_font_style_suffix(name: &str) -> &str {
    const STYLE_SUFFIXES: &[&str] = &[
        "Regular",
        "Medium",
        "Bold",
        "Italic",
        "Light",
        "Thin",
        "Semibold",
        "SemiBold",
        "DemiBold",
        "ExtraLight",
        "UltraLight",
        "ExtraBold",
        "Heavy",
        "Black",
        "Book",
        "Roman",
        "Retina",
    ];

    STYLE_SUFFIXES
        .iter()
        .find_map(|suffix| {
            name.strip_suffix(&format!("-{suffix}"))
                .or_else(|| name.strip_suffix(suffix))
        })
        .unwrap_or(name)
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
        assert_eq!(settings.terminal.font_weight, "400");
        assert_eq!(settings.terminal.font_weight_bold, "700");
        assert_eq!(settings.terminal.line_height, 1.15);
        assert_eq!(settings.terminal.letter_spacing, 0.0);
        assert_eq!(settings.terminal.minimum_contrast_ratio, 4.5);
        assert!(settings.terminal.draw_bold_text_in_bright_colors);
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
            "\"MesloLGS-NF-Regular\", \"MesloLGS NF\", \"SFMono-Regular\", \"Menlo\", monospace"
        );
        assert_eq!(settings.terminal.font_size, 14);
        assert_eq!(settings.terminal.cursor_style, "bar");
        assert_eq!(settings.terminal.font_weight_bold, "400");
        assert_eq!(settings.terminal.minimum_contrast_ratio, 11.0);
        assert!(!settings.terminal.draw_bold_text_in_bright_colors);
    }

    #[test]
    fn parses_iterm2_font_with_family_fallbacks() {
        assert_eq!(
            parse_iterm2_font("JetBrainsMono-Medium 13.6"),
            Some((
                "\"JetBrainsMono-Medium\", \"JetBrainsMono\", \"SFMono-Regular\", \"Menlo\", monospace"
                    .to_string(),
                14
            ))
        );

        assert_eq!(
            parse_iterm2_font("Menlo-Regular 12"),
            Some((
                "\"Menlo-Regular\", \"Menlo\", \"SFMono-Regular\", monospace".to_string(),
                12
            ))
        );
    }

    fn sample_iterm2_profile(guid: &str) -> Dictionary {
        let mut profile = Dictionary::new();
        profile.insert("Guid".to_string(), Value::String(guid.to_string()));
        profile.insert(
            "Normal Font".to_string(),
            Value::String("MesloLGS-NF-Regular 14".to_string()),
        );
        profile.insert("Cursor Type".to_string(), Value::Integer(1.into()));
        profile.insert("Use Bold Font".to_string(), Value::Boolean(false));
        profile.insert("Minimum Contrast".to_string(), Value::Real(0.5));
        profile.insert("Brighten Bold Text".to_string(), Value::Boolean(false));
        profile.insert("ASCII Ligatures".to_string(), Value::Boolean(true));
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
