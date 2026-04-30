#![allow(dead_code)]

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct AppSettings {
    pub version: u32,
    pub theme: ThemeMode,
    pub terminal: TerminalSettings,
    pub vault: VaultSettings,
    pub connection: ConnectionSettings,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum ThemeMode {
    System,
    Light,
    Dark,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct TerminalSettings {
    pub font_family: String,
    pub font_size: u16,
    pub cursor_style: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct VaultSettings {
    pub mode: String,
    pub clear_clipboard_after_seconds: u16,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ConnectionSettings {
    pub default_open_mode: String,
    pub auto_login: bool,
    pub close_tab_on_disconnect: bool,
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            version: 1,
            theme: ThemeMode::System,
            terminal: TerminalSettings {
                font_family: "JetBrains Mono".to_string(),
                font_size: 13,
                cursor_style: "block".to_string(),
            },
            vault: VaultSettings {
                mode: "plain".to_string(),
                clear_clipboard_after_seconds: 30,
            },
            connection: ConnectionSettings {
                default_open_mode: "tab".to_string(),
                auto_login: true,
                close_tab_on_disconnect: false,
            },
        }
    }
}
