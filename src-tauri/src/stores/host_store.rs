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

    pub fn update_folder(&self, folder_id: String, name: String) -> Result<HostDocument> {
        let mut document = self.load()?;
        let next_name = name.trim();

        if next_name.is_empty() {
            return Err(HopdeckError::InvalidRequest(
                "folder name is required".to_string(),
            ));
        }

        if !rename_folder(&mut document.tree, &folder_id, next_name) {
            return Err(HopdeckError::TreeNodeNotFound(folder_id));
        }

        self.save(&document)?;
        Ok(document)
    }

    pub fn delete_folder(&self, folder_id: String) -> Result<HostDocument> {
        let mut document = self.load()?;
        let mut removed_host_ids = Vec::new();

        if !remove_folder(&mut document.tree, &folder_id, &mut removed_host_ids) {
            return Err(HopdeckError::TreeNodeNotFound(folder_id));
        }

        for host_id in &removed_host_ids {
            document.hosts.remove(host_id);
        }
        prune_jump_chains(&mut document, &removed_host_ids);

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
        prune_jump_chains(&mut document, &[host_id]);
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

    pub fn duplicate_host(
        &self,
        host_id: String,
        parent_id: Option<String>,
    ) -> Result<HostDocument> {
        let mut document = self.load()?;
        let source = document
            .hosts
            .get(&host_id)
            .ok_or_else(|| HopdeckError::HostNotFound(host_id.clone()))?
            .clone();
        let new_id = unique_host_id(&document, &source.id);
        let now = Utc::now();
        let mut duplicate = source;
        duplicate.id = new_id.clone();
        duplicate.alias = unique_alias(&document, &format!("{} copy", duplicate.alias));
        duplicate.created_at = Some(now);
        duplicate.updated_at = Some(now);

        let node = TreeNode::HostRef {
            id: format!("node-{new_id}"),
            host_id: new_id.clone(),
        };
        let source_node_id = find_host_ref_node_id(&document.tree, &host_id);

        document.hosts.insert(new_id, duplicate);
        if let Some(parent_id) = parent_id {
            insert_node(&mut document.tree, Some(&parent_id), node)?;
        } else if let Some(source_node_id) = source_node_id {
            insert_after_node(&mut document.tree, &source_node_id, node)?;
        } else {
            insert_node(&mut document.tree, None, node)?;
        }

        self.save(&document)?;
        Ok(document)
    }

    pub fn move_node(
        &self,
        node_id: String,
        parent_id: Option<String>,
        index: Option<usize>,
    ) -> Result<HostDocument> {
        let mut document = self.load()?;
        let node = find_node(&document.tree, &node_id)
            .ok_or_else(|| HopdeckError::TreeNodeNotFound(node_id.clone()))?
            .clone();

        if let Some(parent_id) = parent_id.as_deref() {
            if parent_id == node_id || node_contains_id(&node, parent_id) {
                return Err(HopdeckError::InvalidRequest(
                    "cannot move a folder into itself".to_string(),
                ));
            }

            if !folder_exists(&document.tree, parent_id) {
                return Err(HopdeckError::TreeNodeNotFound(parent_id.to_string()));
            }
        }

        remove_node_by_id(&mut document.tree, &node_id)
            .ok_or_else(|| HopdeckError::TreeNodeNotFound(node_id.clone()))?;
        insert_node_at(&mut document.tree, parent_id.as_deref(), index, node)?;
        self.save(&document)?;
        Ok(document)
    }

    pub fn import_ssh_config_from_default(&self) -> Result<HostDocument> {
        let dirs = BaseDirs::new().ok_or(HopdeckError::DataDirectoryUnavailable)?;
        let path = dirs.home_dir().join(".ssh").join("config");
        let contents = fs::read_to_string(path)?;
        self.import_ssh_config(&contents)
    }

    fn import_ssh_config(&self, contents: &str) -> Result<HostDocument> {
        let entries = parse_ssh_config(contents);
        let mut document = self.load()?;
        if entries.is_empty() {
            return Ok(document);
        }

        let folder_id = unique_folder_id(&document.tree, "folder-imported-ssh-config");
        let mut imported_nodes = Vec::new();
        let mut alias_to_id = BTreeMap::new();
        let mut pending_jumps = Vec::new();
        let now = Utc::now();

        for entry in entries {
            let id = unique_host_id(&document, &slugify(&entry.alias));
            let auth = if entry.identity_file.is_some() {
                HostAuth::Key {
                    identity_file: entry.identity_file.clone(),
                    use_agent: false,
                }
            } else {
                HostAuth::Agent
            };

            alias_to_id.insert(entry.alias.clone(), id.clone());
            pending_jumps.push((id.clone(), entry.proxy_jump.clone()));
            document.hosts.insert(
                id.clone(),
                Host {
                    id: id.clone(),
                    alias: entry.alias,
                    host: entry.host_name.unwrap_or_else(|| id.clone()),
                    user: entry.user.unwrap_or_else(|| {
                        std::env::var("USER").unwrap_or_else(|_| "user".to_string())
                    }),
                    port: entry.port.unwrap_or(22),
                    tags: vec!["ssh-config".to_string()],
                    favorite: false,
                    is_jump_host: false,
                    jump_chain: Vec::new(),
                    auth,
                    notes: "Imported from ~/.ssh/config".to_string(),
                    created_at: Some(now),
                    updated_at: Some(now),
                    last_connected_at: None,
                },
            );
            imported_nodes.push(TreeNode::HostRef {
                id: format!("node-{id}"),
                host_id: id,
            });
        }

        let host_lookup = document.hosts.clone();
        for (host_id, proxy_jump) in pending_jumps {
            let Some(proxy_jump) = proxy_jump else {
                continue;
            };
            let jump_chain = proxy_jump
                .split(',')
                .filter_map(|part| resolve_proxy_jump(part, &alias_to_id, &host_lookup))
                .collect::<Vec<_>>();

            if let Some(host) = document.hosts.get_mut(&host_id) {
                host.jump_chain = jump_chain;
            }
        }

        document.tree.push(TreeNode::Folder {
            id: folder_id,
            name: "Imported SSH Config".to_string(),
            expanded: true,
            children: imported_nodes,
        });
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

fn insert_node_at(
    nodes: &mut Vec<TreeNode>,
    parent_id: Option<&str>,
    index: Option<usize>,
    node: TreeNode,
) -> Result<()> {
    let target = match parent_id {
        None => Some(nodes),
        Some(parent_id) => find_folder_children_mut(nodes, parent_id),
    }
    .ok_or_else(|| HopdeckError::TreeNodeNotFound(parent_id.unwrap_or_default().to_string()))?;

    let index = index.unwrap_or(target.len()).min(target.len());
    target.insert(index, node);
    Ok(())
}

fn find_folder_children_mut<'a>(
    nodes: &'a mut [TreeNode],
    parent_id: &str,
) -> Option<&'a mut Vec<TreeNode>> {
    for node in nodes {
        if let TreeNode::Folder { id, children, .. } = node {
            if id == parent_id {
                return Some(children);
            }

            if let Some(found) = find_folder_children_mut(children, parent_id) {
                return Some(found);
            }
        }
    }

    None
}

fn insert_after_node(nodes: &mut Vec<TreeNode>, node_id: &str, node: TreeNode) -> Result<()> {
    if let Some(index) = nodes.iter().position(|candidate| candidate.id() == node_id) {
        nodes.insert(index + 1, node);
        return Ok(());
    }

    for candidate in nodes {
        if let TreeNode::Folder { children, .. } = candidate {
            if insert_after_node(children, node_id, node.clone()).is_ok() {
                return Ok(());
            }
        }
    }

    Err(HopdeckError::TreeNodeNotFound(node_id.to_string()))
}

fn find_node<'a>(nodes: &'a [TreeNode], node_id: &str) -> Option<&'a TreeNode> {
    for node in nodes {
        if node.id() == node_id {
            return Some(node);
        }

        if let TreeNode::Folder { children, .. } = node {
            if let Some(found) = find_node(children, node_id) {
                return Some(found);
            }
        }
    }

    None
}

fn remove_node_by_id(nodes: &mut Vec<TreeNode>, node_id: &str) -> Option<TreeNode> {
    if let Some(index) = nodes.iter().position(|node| node.id() == node_id) {
        return Some(nodes.remove(index));
    }

    for node in nodes {
        if let TreeNode::Folder { children, .. } = node {
            if let Some(removed) = remove_node_by_id(children, node_id) {
                return Some(removed);
            }
        }
    }

    None
}

fn node_contains_id(node: &TreeNode, node_id: &str) -> bool {
    match node {
        TreeNode::Folder { children, .. } => children
            .iter()
            .any(|child| child.id() == node_id || node_contains_id(child, node_id)),
        TreeNode::HostRef { .. } => false,
    }
}

fn folder_exists(nodes: &[TreeNode], folder_id: &str) -> bool {
    nodes.iter().any(|node| match node {
        TreeNode::Folder { id, children, .. } => {
            id == folder_id || folder_exists(children, folder_id)
        }
        TreeNode::HostRef { .. } => false,
    })
}

fn find_host_ref_node_id(nodes: &[TreeNode], host_id: &str) -> Option<String> {
    for node in nodes {
        match node {
            TreeNode::Folder { children, .. } => {
                if let Some(found) = find_host_ref_node_id(children, host_id) {
                    return Some(found);
                }
            }
            TreeNode::HostRef {
                id,
                host_id: node_host_id,
            } if node_host_id == host_id => return Some(id.clone()),
            TreeNode::HostRef { .. } => {}
        }
    }

    None
}

fn unique_host_id(document: &HostDocument, base: &str) -> String {
    let base = if base.trim().is_empty() {
        "host".to_string()
    } else {
        slugify(base)
    };
    let mut candidate = base.clone();
    let mut index = 2;

    while document.hosts.contains_key(&candidate) {
        candidate = format!("{base}-{index}");
        index += 1;
    }

    candidate
}

fn unique_alias(document: &HostDocument, base: &str) -> String {
    let mut candidate = base.to_string();
    let mut index = 2;

    while document.hosts.values().any(|host| host.alias == candidate) {
        candidate = format!("{base} {index}");
        index += 1;
    }

    candidate
}

fn unique_folder_id(nodes: &[TreeNode], base: &str) -> String {
    let mut candidate = base.to_string();
    let mut index = 2;

    while find_node(nodes, &candidate).is_some() {
        candidate = format!("{base}-{index}");
        index += 1;
    }

    candidate
}

trait TreeNodeId {
    fn id(&self) -> &str;
}

impl TreeNodeId for TreeNode {
    fn id(&self) -> &str {
        match self {
            TreeNode::Folder { id, .. } => id,
            TreeNode::HostRef { id, .. } => id,
        }
    }
}

fn rename_folder(nodes: &mut [TreeNode], folder_id: &str, name: &str) -> bool {
    for node in nodes {
        if let TreeNode::Folder {
            id,
            name: folder_name,
            children,
            ..
        } = node
        {
            if id == folder_id {
                *folder_name = name.to_string();
                return true;
            }

            if rename_folder(children, folder_id, name) {
                return true;
            }
        }
    }

    false
}

fn remove_folder(
    nodes: &mut Vec<TreeNode>,
    folder_id: &str,
    removed_host_ids: &mut Vec<String>,
) -> bool {
    if let Some(index) = nodes.iter().position(|node| match node {
        TreeNode::Folder { id, .. } => id == folder_id,
        TreeNode::HostRef { .. } => false,
    }) {
        let node = nodes.remove(index);
        collect_host_refs(&node, removed_host_ids);
        return true;
    }

    for node in nodes {
        if let TreeNode::Folder { children, .. } = node {
            if remove_folder(children, folder_id, removed_host_ids) {
                return true;
            }
        }
    }

    false
}

fn collect_host_refs(node: &TreeNode, host_ids: &mut Vec<String>) {
    match node {
        TreeNode::Folder { children, .. } => {
            for child in children {
                collect_host_refs(child, host_ids);
            }
        }
        TreeNode::HostRef { host_id, .. } => host_ids.push(host_id.clone()),
    }
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

fn prune_jump_chains(document: &mut HostDocument, removed_host_ids: &[String]) {
    if removed_host_ids.is_empty() {
        return;
    }

    for host in document.hosts.values_mut() {
        host.jump_chain
            .retain(|jump_host_id| !removed_host_ids.contains(jump_host_id));
    }
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
struct SshConfigEntry {
    alias: String,
    host_name: Option<String>,
    user: Option<String>,
    port: Option<u16>,
    identity_file: Option<String>,
    proxy_jump: Option<String>,
}

fn parse_ssh_config(contents: &str) -> Vec<SshConfigEntry> {
    let mut entries = Vec::new();
    let mut current_aliases: Vec<String> = Vec::new();
    let mut current = SshConfigEntry::default();
    let mut skip_current = false;

    for raw_line in contents.lines() {
        let line = raw_line
            .split_once('#')
            .map(|(before_comment, _)| before_comment)
            .unwrap_or(raw_line)
            .trim();

        if line.is_empty() {
            continue;
        }

        let mut parts = line.splitn(2, char::is_whitespace);
        let keyword = parts.next().unwrap_or_default().to_ascii_lowercase();
        let value = parts.next().unwrap_or_default().trim();

        if keyword == "host" {
            push_ssh_config_entries(&mut entries, &current_aliases, &current, skip_current);
            current = SshConfigEntry::default();
            current_aliases = value
                .split_whitespace()
                .filter(|alias| !alias.starts_with('!'))
                .map(ToString::to_string)
                .collect();
            skip_current = current_aliases
                .iter()
                .any(|alias| alias.contains('*') || alias.contains('?'));
            continue;
        }

        if current_aliases.is_empty() || skip_current {
            continue;
        }

        match keyword.as_str() {
            "hostname" => current.host_name = Some(value.to_string()),
            "user" => current.user = Some(value.to_string()),
            "port" => current.port = value.parse::<u16>().ok(),
            "identityfile" => current.identity_file = Some(value.to_string()),
            "proxyjump" => {
                if !value.eq_ignore_ascii_case("none") {
                    current.proxy_jump = Some(value.to_string());
                }
            }
            _ => {}
        }
    }

    push_ssh_config_entries(&mut entries, &current_aliases, &current, skip_current);
    entries
}

fn push_ssh_config_entries(
    entries: &mut Vec<SshConfigEntry>,
    aliases: &[String],
    template: &SshConfigEntry,
    skip: bool,
) {
    if skip {
        return;
    }

    for alias in aliases {
        if alias.trim().is_empty() {
            continue;
        }

        let mut entry = template.clone();
        entry.alias = alias.clone();
        entries.push(entry);
    }
}

fn resolve_proxy_jump(
    proxy_jump: &str,
    imported_aliases: &BTreeMap<String, String>,
    hosts: &BTreeMap<String, Host>,
) -> Option<String> {
    let proxy_jump = proxy_jump.trim();
    if proxy_jump.is_empty() || proxy_jump.eq_ignore_ascii_case("none") {
        return None;
    }

    let host_part = proxy_jump
        .rsplit_once('@')
        .map(|(_, host)| host)
        .unwrap_or(proxy_jump)
        .split_once(':')
        .map(|(host, _)| host)
        .unwrap_or(proxy_jump);

    imported_aliases.get(host_part).cloned().or_else(|| {
        hosts
            .iter()
            .find(|(id, host)| {
                id.as_str() == host_part || host.alias == host_part || host.host == host_part
            })
            .map(|(id, _)| id.clone())
    })
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
    fn renames_folder() {
        let dir = tempdir().unwrap();
        let store = HostStore::with_path(dir.path().join("hosts.json"));

        let created = store.create_folder(None, "Production".to_string()).unwrap();
        let folder_id = match &created.tree[0] {
            TreeNode::Folder { id, .. } => id.clone(),
            TreeNode::HostRef { .. } => panic!("expected folder"),
        };

        let document = store
            .update_folder(folder_id, "Production SSH".to_string())
            .unwrap();

        assert!(matches!(
            &document.tree[0],
            TreeNode::Folder { name, .. } if name == "Production SSH"
        ));
    }

    #[test]
    fn deletes_folder_and_nested_hosts() {
        let dir = tempdir().unwrap();
        let store = HostStore::with_path(dir.path().join("hosts.json"));
        let document = HostDocument::sample();

        store.replace_document(document).unwrap();
        let document = store
            .delete_folder("folder-production-jump-hosts".to_string())
            .unwrap();

        assert!(!document.hosts.contains_key("jump-prod"));
        assert_eq!(
            document.hosts["prod-app-01"].jump_chain,
            Vec::<String>::new()
        );
        assert!(!document.tree.iter().any(|node| match node {
            TreeNode::Folder { id, .. } => id == "folder-production-jump-hosts",
            TreeNode::HostRef { .. } => false,
        }));
    }

    #[test]
    fn duplicates_host_near_source_node() {
        let dir = tempdir().unwrap();
        let store = HostStore::with_path(dir.path().join("hosts.json"));
        store.replace_document(HostDocument::sample()).unwrap();

        let document = store
            .duplicate_host("prod-app-01".to_string(), None)
            .unwrap();

        assert!(document.hosts.contains_key("prod-app-01-2"));
        assert_eq!(document.hosts["prod-app-01-2"].alias, "prod-app-01 copy");
        assert!(matches!(
            &document.tree[0],
            TreeNode::Folder { children, .. } if matches!(
                &children[1],
                TreeNode::Folder { children, .. } if matches!(
                    (&children[0], &children[1]),
                    (
                        TreeNode::HostRef { host_id: first, .. },
                        TreeNode::HostRef { host_id: second, .. }
                    ) if first == "prod-app-01" && second == "prod-app-01-2"
                )
            )
        ));
    }

    #[test]
    fn moves_node_to_root() {
        let dir = tempdir().unwrap();
        let store = HostStore::with_path(dir.path().join("hosts.json"));
        store.replace_document(HostDocument::sample()).unwrap();

        let document = store
            .move_node("node-prod-app-01".to_string(), None, Some(0))
            .unwrap();

        assert!(matches!(
            &document.tree[0],
            TreeNode::HostRef { host_id, .. } if host_id == "prod-app-01"
        ));
        assert!(!matches!(
            &document.tree[1],
            TreeNode::HostRef { host_id, .. } if host_id == "prod-app-01"
        ));
    }

    #[test]
    fn refuses_to_move_folder_into_descendant() {
        let dir = tempdir().unwrap();
        let store = HostStore::with_path(dir.path().join("hosts.json"));
        store.replace_document(HostDocument::sample()).unwrap();

        let error = store
            .move_node(
                "folder-production".to_string(),
                Some("folder-production-apps".to_string()),
                None,
            )
            .unwrap_err();

        assert!(error.to_string().contains("cannot move"));
    }

    #[test]
    fn parses_common_ssh_config_entries_and_skips_wildcards() {
        let entries = parse_ssh_config(
            r#"
Host bastion
  HostName bastion.example.com
  User ops
  Port 2222
  IdentityFile ~/.ssh/bastion

Host prod-* wildcard
  User ignored

Host app
  HostName 10.0.1.20
  User app
  ProxyJump bastion
"#,
        );

        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0].alias, "bastion");
        assert_eq!(entries[0].port, Some(2222));
        assert_eq!(entries[0].identity_file.as_deref(), Some("~/.ssh/bastion"));
        assert_eq!(entries[1].alias, "app");
        assert_eq!(entries[1].proxy_jump.as_deref(), Some("bastion"));
    }

    #[test]
    fn imports_ssh_config_into_folder() {
        let dir = tempdir().unwrap();
        let store = HostStore::with_path(dir.path().join("hosts.json"));
        store.replace_document(HostDocument::default()).unwrap();

        let document = store
            .import_ssh_config(
                r#"
Host bastion
  HostName bastion.example.com
  User ops

Host app
  HostName 10.0.1.20
  User app
  ProxyJump bastion
"#,
            )
            .unwrap();

        assert_eq!(document.hosts["app"].jump_chain, vec!["bastion"]);
        assert!(matches!(
            &document.tree[0],
            TreeNode::Folder { name, children, .. } if name == "Imported SSH Config" && children.len() == 2
        ));
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
