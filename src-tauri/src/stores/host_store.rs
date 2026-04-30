use std::collections::BTreeMap;
use std::fs;
use std::path::PathBuf;

use chrono::{DateTime, Utc};
use directories::BaseDirs;
use serde::Deserialize;
use uuid::Uuid;

use crate::errors::{HopdeckError, Result};
use crate::models::{Host, HostAuth, HostDocument, TreeNode};

#[derive(Debug, Clone)]
pub struct HostStore {
    path: PathBuf,
}

impl HostStore {
    pub fn default() -> Result<Self> {
        Ok(Self {
            path: default_hopdeck_dir()?.join("hosts.json"),
        })
    }

    #[cfg(test)]
    pub fn with_path(path: PathBuf) -> Self {
        Self { path }
    }

    pub fn load(&self) -> Result<HostDocument> {
        if !self.path.exists() {
            let document = HostDocument::sample();
            self.save(&document)?;
            return Ok(document);
        }

        let data = fs::read_to_string(&self.path)?;
        if data.trim().is_empty() {
            let document = HostDocument::sample();
            self.save(&document)?;
            return Ok(document);
        }

        let value = serde_json::from_str::<serde_json::Value>(&data)?;
        match serde_json::from_value::<HostDocument>(value.clone()) {
            Ok(document) => Ok(document),
            Err(error) => {
                let document =
                    migrate_legacy_document(value).map_err(|_| HopdeckError::Json(error))?;
                self.save(&document)?;
                Ok(document)
            }
        }
    }

    pub fn replace_document(&self, document: HostDocument) -> Result<HostDocument> {
        self.save(&document)?;
        Ok(document)
    }

    pub fn create_folder(&self, parent_id: Option<String>, name: String) -> Result<HostDocument> {
        let mut document = self.load()?;
        let node = TreeNode::Folder {
            id: format!("folder-{}", Uuid::new_v4()),
            name,
            expanded: true,
            children: Vec::new(),
        };

        insert_node(&mut document.tree, parent_id.as_deref(), node)?;
        self.save(&document)?;
        Ok(document)
    }

    pub fn create_host(&self, parent_id: Option<String>, mut host: Host) -> Result<HostDocument> {
        let mut document = self.load()?;
        let now = Utc::now();
        host.created_at = Some(now);
        host.updated_at = Some(now);

        let node = TreeNode::HostRef {
            id: format!("node-{}", host.id),
            host_id: host.id.clone(),
        };

        document.hosts.insert(host.id.clone(), host);
        insert_node(&mut document.tree, parent_id.as_deref(), node)?;
        self.save(&document)?;
        Ok(document)
    }

    pub fn update_host(&self, mut host: Host) -> Result<HostDocument> {
        let mut document = self.load()?;
        if !document.hosts.contains_key(&host.id) {
            return Err(HopdeckError::HostNotFound(host.id));
        }

        host.updated_at = Some(Utc::now());
        document.hosts.insert(host.id.clone(), host);
        self.save(&document)?;
        Ok(document)
    }

    pub fn delete_host(&self, host_id: String) -> Result<HostDocument> {
        let mut document = self.load()?;
        document.hosts.remove(&host_id);
        remove_host_refs(&mut document.tree, &host_id);
        self.save(&document)?;
        Ok(document)
    }

    pub fn toggle_favorite(&self, host_id: String) -> Result<HostDocument> {
        let mut document = self.load()?;
        let host = document
            .hosts
            .get_mut(&host_id)
            .ok_or_else(|| HopdeckError::HostNotFound(host_id.clone()))?;
        host.favorite = !host.favorite;
        host.updated_at = Some(Utc::now());
        self.save(&document)?;
        Ok(document)
    }

    fn save(&self, document: &HostDocument) -> Result<()> {
        if let Some(parent) = self.path.parent() {
            fs::create_dir_all(parent)?;
        }

        let data = serde_json::to_string_pretty(document)?;
        fs::write(&self.path, data)?;
        Ok(())
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct LegacyDocument {
    hosts: Vec<LegacyHost>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct LegacyHost {
    id: String,
    alias: String,
    host: String,
    user: String,
    port: u16,
    #[serde(default)]
    group: Option<String>,
    #[serde(default)]
    tags: Vec<String>,
    #[serde(default)]
    favorite: bool,
    #[serde(default)]
    is_jump_host: bool,
    #[serde(default)]
    jump_chain: Vec<String>,
    auth: HostAuth,
    #[serde(default)]
    notes: String,
    created_at: Option<DateTime<Utc>>,
    updated_at: Option<DateTime<Utc>>,
    last_connected_at: Option<DateTime<Utc>>,
}

fn migrate_legacy_document(
    value: serde_json::Value,
) -> std::result::Result<HostDocument, serde_json::Error> {
    let legacy = serde_json::from_value::<LegacyDocument>(value)?;
    let mut hosts = BTreeMap::new();
    let mut grouped_nodes = BTreeMap::<String, Vec<TreeNode>>::new();

    for legacy_host in legacy.hosts {
        let group = legacy_host
            .group
            .clone()
            .filter(|group| !group.trim().is_empty())
            .unwrap_or_else(|| "Hosts".to_string());
        let is_jump_host = legacy_host.is_jump_host
            || legacy_host
                .tags
                .iter()
                .any(|tag| tag.eq_ignore_ascii_case("jump"))
            || group.to_ascii_lowercase().contains("jump");
        let host = Host {
            id: legacy_host.id,
            alias: legacy_host.alias,
            host: legacy_host.host,
            user: legacy_host.user,
            port: legacy_host.port,
            tags: legacy_host.tags,
            favorite: legacy_host.favorite,
            is_jump_host,
            jump_chain: legacy_host.jump_chain,
            auth: legacy_host.auth,
            notes: legacy_host.notes,
            created_at: legacy_host.created_at,
            updated_at: legacy_host.updated_at,
            last_connected_at: legacy_host.last_connected_at,
        };

        grouped_nodes
            .entry(group)
            .or_default()
            .push(TreeNode::HostRef {
                id: format!("node-{}", host.id),
                host_id: host.id.clone(),
            });
        hosts.insert(host.id.clone(), host);
    }

    let tree = grouped_nodes
        .into_iter()
        .map(|(group, children)| TreeNode::Folder {
            id: format!("folder-{}", slugify(&group)),
            name: group,
            expanded: true,
            children,
        })
        .collect();

    Ok(HostDocument {
        version: HostDocument::CURRENT_VERSION,
        tree,
        hosts,
    })
}

fn slugify(value: &str) -> String {
    let slug = value
        .chars()
        .map(|ch| {
            if ch.is_ascii_alphanumeric() {
                ch.to_ascii_lowercase()
            } else {
                '-'
            }
        })
        .collect::<String>()
        .split('-')
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>()
        .join("-");

    if slug.is_empty() {
        Uuid::new_v4().to_string()
    } else {
        slug
    }
}

fn default_hopdeck_dir() -> Result<PathBuf> {
    let dirs = BaseDirs::new().ok_or(HopdeckError::DataDirectoryUnavailable)?;
    Ok(dirs.home_dir().join(".hopdeck"))
}

fn insert_node(nodes: &mut Vec<TreeNode>, parent_id: Option<&str>, node: TreeNode) -> Result<()> {
    match parent_id {
        None => {
            nodes.push(node);
            Ok(())
        }
        Some(parent_id) => {
            if insert_node_in_folder(nodes, parent_id, node) {
                Ok(())
            } else {
                Err(HopdeckError::TreeNodeNotFound(parent_id.to_string()))
            }
        }
    }
}

fn insert_node_in_folder(nodes: &mut [TreeNode], parent_id: &str, node: TreeNode) -> bool {
    for item in nodes {
        if let TreeNode::Folder { id, children, .. } = item {
            if id == parent_id {
                children.push(node);
                return true;
            }
            if insert_node_in_folder(children, parent_id, node.clone()) {
                return true;
            }
        }
    }
    false
}

fn remove_host_refs(nodes: &mut Vec<TreeNode>, host_id: &str) {
    nodes.retain(|node| match node {
        TreeNode::Folder { .. } => true,
        TreeNode::HostRef {
            host_id: node_host_id,
            ..
        } => node_host_id != host_id,
    });

    for node in nodes {
        if let TreeNode::Folder { children, .. } = node {
            remove_host_refs(children, host_id);
        }
    }
}

#[cfg(test)]
mod tests {
    use tempfile::tempdir;

    use super::*;

    #[test]
    fn round_trips_sample_document() {
        let dir = tempdir().unwrap();
        let store = HostStore::with_path(dir.path().join("hosts.json"));
        let document = HostDocument::sample();

        store.replace_document(document.clone()).unwrap();

        assert_eq!(store.load().unwrap(), document);
    }

    #[test]
    fn creates_root_folder() {
        let dir = tempdir().unwrap();
        let store = HostStore::with_path(dir.path().join("hosts.json"));

        let document = store.create_folder(None, "Production".to_string()).unwrap();

        assert!(document.tree.iter().any(|node| match node {
            TreeNode::Folder { name, .. } => name == "Production",
            TreeNode::HostRef { .. } => false,
        }));
    }

    #[test]
    fn migrates_legacy_grouped_hosts() {
        let legacy = serde_json::json!({
            "version": 1,
            "hosts": [
                {
                    "id": "jump-prod",
                    "alias": "jump-prod",
                    "host": "1.2.3.4",
                    "user": "zane",
                    "port": 22,
                    "group": "Jump Hosts",
                    "tags": ["jump", "prod"],
                    "jumpChain": [],
                    "auth": { "type": "agent" },
                    "notes": ""
                }
            ]
        });

        let document = migrate_legacy_document(legacy).unwrap();

        assert_eq!(document.version, HostDocument::CURRENT_VERSION);
        assert!(document.hosts["jump-prod"].is_jump_host);
        assert!(matches!(
            &document.tree[0],
            TreeNode::Folder { name, children, .. } if name == "Jump Hosts" && children.len() == 1
        ));
    }
}
