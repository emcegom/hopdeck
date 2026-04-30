use std::collections::{BTreeMap, BTreeSet};

use serde::{Deserialize, Serialize};

use super::Host;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct HostDocument {
    pub version: u32,
    #[serde(default)]
    pub tree: Vec<TreeNode>,
    #[serde(default)]
    pub hosts: BTreeMap<String, Host>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(
    tag = "type",
    rename_all = "camelCase",
    rename_all_fields = "camelCase"
)]
pub enum TreeNode {
    Folder {
        id: String,
        name: String,
        #[serde(default)]
        expanded: bool,
        #[serde(default)]
        children: Vec<TreeNode>,
    },
    HostRef {
        id: String,
        #[serde(alias = "host_id")]
        host_id: String,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct TreeValidationIssue {
    pub severity: ValidationSeverity,
    pub node_id: Option<String>,
    pub host_id: Option<String>,
    pub message: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum ValidationSeverity {
    Warning,
    Error,
}

impl HostDocument {
    pub const CURRENT_VERSION: u32 = 2;

    pub fn sample() -> Self {
        let jump = Host::sample_jump();
        let target = Host::sample_target();
        let mut hosts = BTreeMap::new();
        hosts.insert(jump.id.clone(), jump);
        hosts.insert(target.id.clone(), target);

        Self {
            version: 2,
            tree: vec![TreeNode::Folder {
                id: "folder-production".to_string(),
                name: "Production".to_string(),
                expanded: true,
                children: vec![
                    TreeNode::Folder {
                        id: "folder-production-jump-hosts".to_string(),
                        name: "Jump Hosts".to_string(),
                        expanded: true,
                        children: vec![TreeNode::HostRef {
                            id: "node-jump-prod".to_string(),
                            host_id: "jump-prod".to_string(),
                        }],
                    },
                    TreeNode::Folder {
                        id: "folder-production-apps".to_string(),
                        name: "Apps".to_string(),
                        expanded: true,
                        children: vec![TreeNode::HostRef {
                            id: "node-prod-app-01".to_string(),
                            host_id: "prod-app-01".to_string(),
                        }],
                    },
                ],
            }],
            hosts,
        }
    }

    pub fn validate(&self) -> Vec<TreeValidationIssue> {
        let mut issues = Vec::new();
        let mut node_ids = BTreeSet::new();
        let mut referenced_hosts = BTreeSet::new();

        for node in &self.tree {
            validate_node(
                node,
                &self.hosts,
                &mut node_ids,
                &mut referenced_hosts,
                &mut issues,
            );
        }

        for (key, host) in &self.hosts {
            if key != &host.id {
                issues.push(TreeValidationIssue::error(
                    None,
                    Some(host.id.clone()),
                    format!("host map key '{key}' does not match host id '{}'", host.id),
                ));
            }

            if host.id.trim().is_empty() {
                issues.push(TreeValidationIssue::error(
                    None,
                    Some(host.id.clone()),
                    "host id is required".to_string(),
                ));
            }
            if host.alias.trim().is_empty() {
                issues.push(TreeValidationIssue::error(
                    None,
                    Some(host.id.clone()),
                    "host alias is required".to_string(),
                ));
            }
            if host.host.trim().is_empty() {
                issues.push(TreeValidationIssue::error(
                    None,
                    Some(host.id.clone()),
                    "host address is required".to_string(),
                ));
            }
            if host.user.trim().is_empty() {
                issues.push(TreeValidationIssue::error(
                    None,
                    Some(host.id.clone()),
                    "host user is required".to_string(),
                ));
            }
            if host.port == 0 {
                issues.push(TreeValidationIssue::error(
                    None,
                    Some(host.id.clone()),
                    "host port must be greater than 0".to_string(),
                ));
            }

            let mut chain_ids = BTreeSet::new();
            for jump_host_id in &host.jump_chain {
                if jump_host_id == &host.id {
                    issues.push(TreeValidationIssue::error(
                        None,
                        Some(host.id.clone()),
                        "host cannot jump through itself".to_string(),
                    ));
                }
                if !self.hosts.contains_key(jump_host_id) {
                    issues.push(TreeValidationIssue::error(
                        None,
                        Some(host.id.clone()),
                        format!("jump host '{jump_host_id}' does not exist"),
                    ));
                }
                if !chain_ids.insert(jump_host_id) {
                    issues.push(TreeValidationIssue::warning(
                        None,
                        Some(host.id.clone()),
                        format!("jump host '{jump_host_id}' is duplicated"),
                    ));
                }
            }
        }

        for host_id in self.hosts.keys() {
            if !referenced_hosts.contains(host_id) {
                issues.push(TreeValidationIssue::warning(
                    None,
                    Some(host_id.clone()),
                    "host is not referenced by the tree".to_string(),
                ));
            }
        }

        issues
    }

    #[allow(dead_code)]
    pub fn validation_errors(&self) -> Vec<TreeValidationIssue> {
        self.validate()
            .into_iter()
            .filter(|issue| issue.severity == ValidationSeverity::Error)
            .collect()
    }
}

impl Default for HostDocument {
    fn default() -> Self {
        Self {
            version: Self::CURRENT_VERSION,
            tree: Vec::new(),
            hosts: BTreeMap::new(),
        }
    }
}

impl TreeValidationIssue {
    pub fn error(node_id: Option<String>, host_id: Option<String>, message: String) -> Self {
        Self {
            severity: ValidationSeverity::Error,
            node_id,
            host_id,
            message,
        }
    }

    pub fn warning(node_id: Option<String>, host_id: Option<String>, message: String) -> Self {
        Self {
            severity: ValidationSeverity::Warning,
            node_id,
            host_id,
            message,
        }
    }
}

fn validate_node(
    node: &TreeNode,
    hosts: &BTreeMap<String, Host>,
    node_ids: &mut BTreeSet<String>,
    referenced_hosts: &mut BTreeSet<String>,
    issues: &mut Vec<TreeValidationIssue>,
) {
    match node {
        TreeNode::Folder {
            id, name, children, ..
        } => {
            if id.trim().is_empty() {
                issues.push(TreeValidationIssue::error(
                    Some(id.clone()),
                    None,
                    "tree node id is required".to_string(),
                ));
            }
            if !node_ids.insert(id.clone()) {
                issues.push(TreeValidationIssue::error(
                    Some(id.clone()),
                    None,
                    format!("duplicate tree node id '{id}'"),
                ));
            }
            if name.trim().is_empty() {
                issues.push(TreeValidationIssue::error(
                    Some(id.clone()),
                    None,
                    "folder name is required".to_string(),
                ));
            }
            for child in children {
                validate_node(child, hosts, node_ids, referenced_hosts, issues);
            }
        }
        TreeNode::HostRef { id, host_id } => {
            if id.trim().is_empty() {
                issues.push(TreeValidationIssue::error(
                    Some(id.clone()),
                    Some(host_id.clone()),
                    "tree node id is required".to_string(),
                ));
            }
            if !node_ids.insert(id.clone()) {
                issues.push(TreeValidationIssue::error(
                    Some(id.clone()),
                    Some(host_id.clone()),
                    format!("duplicate tree node id '{id}'"),
                ));
            }
            if !hosts.contains_key(host_id) {
                issues.push(TreeValidationIssue::error(
                    Some(id.clone()),
                    Some(host_id.clone()),
                    format!("host reference '{host_id}' does not exist"),
                ));
            } else {
                referenced_hosts.insert(host_id.clone());
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validation_reports_missing_host_refs_and_duplicate_node_ids() {
        let document = HostDocument {
            version: HostDocument::CURRENT_VERSION,
            tree: vec![
                TreeNode::HostRef {
                    id: "node-1".to_string(),
                    host_id: "missing".to_string(),
                },
                TreeNode::Folder {
                    id: "node-1".to_string(),
                    name: "".to_string(),
                    expanded: false,
                    children: Vec::new(),
                },
            ],
            hosts: BTreeMap::new(),
        };

        let errors = document.validation_errors();
        assert!(errors
            .iter()
            .any(|issue| issue.message.contains("does not exist")));
        assert!(errors
            .iter()
            .any(|issue| issue.message.contains("duplicate tree node id")));
        assert!(errors
            .iter()
            .any(|issue| issue.message.contains("folder name is required")));
    }
}
