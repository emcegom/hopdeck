#![allow(dead_code)]

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct AppSettings {
    #[serde(default = "default_version")]
    pub version: u32,
    #[serde(default)]
    pub theme: ThemeMode,
    #[serde(default)]
    pub terminal: TerminalSettings,
    #[serde(default)]
    pub vault: VaultSettings,
    #[serde(default)]
    pub connection: ConnectionSettings,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum ThemeMode {
    System,
    Light,
    Dark,
}

impl Default for ThemeMode {
    fn default() -> Self {
        Self::System
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct TerminalSettings {
    #[serde(default = "default_font_family")]
    pub font_family: String,
    #[serde(default = "default_font_size")]
    pub font_size: u16,
    #[serde(default = "default_cursor_style")]
    pub cursor_style: String,
    #[serde(default)]
    pub background_blur: u16,
    #[serde(default = "default_background_opacity")]
    pub background_opacity: u8,
    #[serde(default)]
    pub colors: TerminalColors,
}

impl Default for TerminalSettings {
    fn default() -> Self {
        Self {
            font_family: default_font_family(),
            font_size: default_font_size(),
            cursor_style: default_cursor_style(),
            background_blur: 0,
            background_opacity: default_background_opacity(),
            colors: TerminalColors::default(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct TerminalColors {
    #[serde(default = "default_terminal_background")]
    pub background: String,
    #[serde(default = "default_terminal_foreground")]
    pub foreground: String,
    #[serde(default = "default_terminal_cursor")]
    pub cursor: String,
    #[serde(default = "default_terminal_selection")]
    pub selection: String,
    #[serde(default = "default_terminal_ansi")]
    pub ansi: Vec<String>,
}

impl Default for TerminalColors {
    fn default() -> Self {
        Self {
            background: default_terminal_background(),
            foreground: default_terminal_foreground(),
            cursor: default_terminal_cursor(),
            selection: default_terminal_selection(),
            ansi: default_terminal_ansi(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct VaultSettings {
    #[serde(default = "default_vault_mode")]
    pub mode: String,
    #[serde(default = "default_clear_clipboard_after_seconds")]
    pub clear_clipboard_after_seconds: u16,
}

impl Default for VaultSettings {
    fn default() -> Self {
        Self {
            mode: default_vault_mode(),
            clear_clipboard_after_seconds: default_clear_clipboard_after_seconds(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ConnectionSettings {
    #[serde(default = "default_open_mode")]
    pub default_open_mode: String,
    #[serde(default = "default_auto_login")]
    pub auto_login: bool,
    #[serde(default)]
    pub close_tab_on_disconnect: bool,
}

impl Default for ConnectionSettings {
    fn default() -> Self {
        Self {
            default_open_mode: default_open_mode(),
            auto_login: default_auto_login(),
            close_tab_on_disconnect: false,
        }
    }
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            version: 1,
            theme: ThemeMode::default(),
            terminal: TerminalSettings::default(),
            vault: VaultSettings::default(),
            connection: ConnectionSettings::default(),
        }
    }
}

fn default_version() -> u32 {
    1
}

fn default_font_family() -> String {
    "JetBrains Mono".to_string()
}

fn default_font_size() -> u16 {
    13
}

fn default_cursor_style() -> String {
    "block".to_string()
}

fn default_background_opacity() -> u8 {
    100
}

fn default_terminal_background() -> String {
    "#0F1720".to_string()
}

fn default_terminal_foreground() -> String {
    "#DBE7F3".to_string()
}

fn default_terminal_cursor() -> String {
    "#41B6C8".to_string()
}

fn default_terminal_selection() -> String {
    "#24384A".to_string()
}

fn default_terminal_ansi() -> Vec<String> {
    [
        "#172331", "#EF8A80", "#7FD19B", "#E5C15D", "#69A7E8", "#B99CFF", "#41B6C8", "#DBE7F3",
        "#8EA0B4", "#FFB8B0", "#A6E3B6", "#F4D675", "#9BC7FF", "#CFB8FF", "#75D7E4", "#F3F7FB",
    ]
    .iter()
    .map(|color| (*color).to_string())
    .collect()
}

fn default_vault_mode() -> String {
    "plain".to_string()
}

fn default_clear_clipboard_after_seconds() -> u16 {
    30
}

fn default_open_mode() -> String {
    "tab".to_string()
}

fn default_auto_login() -> bool {
    true
}
