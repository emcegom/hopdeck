use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct Host {
    pub id: String,
    pub alias: String,
    pub host: String,
    pub user: String,
    pub port: u16,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub favorite: bool,
    #[serde(default)]
    pub is_jump_host: bool,
    #[serde(default)]
    pub jump_chain: Vec<String>,
    pub auth: HostAuth,
    #[serde(default)]
    pub notes: String,
    pub created_at: Option<DateTime<Utc>>,
    pub updated_at: Option<DateTime<Utc>>,
    pub last_connected_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(
    tag = "type",
    rename_all = "camelCase",
    rename_all_fields = "camelCase"
)]
pub enum HostAuth {
    Password {
        password_ref: Option<String>,
        auto_login: bool,
    },
    Key {
        identity_file: Option<String>,
        use_agent: bool,
    },
    Agent,
    None,
}

impl Host {
    pub fn sample_jump() -> Self {
        Self {
            id: "jump-prod".to_string(),
            alias: "jump-prod".to_string(),
            host: "1.2.3.4".to_string(),
            user: "zane".to_string(),
            port: 22,
            tags: vec!["prod".to_string(), "jump".to_string()],
            favorite: false,
            is_jump_host: true,
            jump_chain: vec![],
            auth: HostAuth::Password {
                password_ref: Some("password:jump-prod".to_string()),
                auto_login: true,
            },
            notes: "Production jump host.".to_string(),
            created_at: None,
            updated_at: None,
            last_connected_at: None,
        }
    }

    pub fn sample_target() -> Self {
        Self {
            id: "prod-app-01".to_string(),
            alias: "prod-app-01".to_string(),
            host: "10.0.1.20".to_string(),
            user: "app".to_string(),
            port: 22,
            tags: vec!["prod".to_string(), "app".to_string()],
            favorite: true,
            is_jump_host: false,
            jump_chain: vec!["jump-prod".to_string()],
            auth: HostAuth::Password {
                password_ref: Some("password:prod-app-01".to_string()),
                auto_login: true,
            },
            notes: "Production app server.".to_string(),
            created_at: None,
            updated_at: None,
            last_connected_at: None,
        }
    }
}
