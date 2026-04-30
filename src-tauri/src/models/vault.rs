#![allow(dead_code)]

use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct VaultDocument {
    pub version: u32,
    pub mode: VaultMode,
    #[serde(default)]
    pub items: BTreeMap<String, VaultItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum VaultMode {
    Plain,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct VaultItem {
    pub username: String,
    pub password: String,
}

impl Default for VaultDocument {
    fn default() -> Self {
        Self {
            version: 1,
            mode: VaultMode::Plain,
            items: BTreeMap::new(),
        }
    }
}
