use crate::{
    errors::Result,
    models::{AppSettings, Host, HostDocument, TreeValidationIssue, VaultDocument},
    ssh::{self, SshCommand},
    stores::{HostStore, SettingsStore, VaultStore},
};

#[tauri::command]
pub fn get_host_document() -> Result<HostDocument> {
    HostStore::default()?.load()
}

#[tauri::command]
pub fn save_host_document(document: HostDocument) -> Result<HostDocument> {
    HostStore::default()?.replace_document(document)
}

#[tauri::command]
pub fn create_folder(parent_id: Option<String>, name: String) -> Result<HostDocument> {
    HostStore::default()?.create_folder(parent_id, name)
}

#[tauri::command]
pub fn update_folder(folder_id: String, name: String) -> Result<HostDocument> {
    HostStore::default()?.update_folder(folder_id, name)
}

#[tauri::command]
pub fn delete_folder(folder_id: String) -> Result<HostDocument> {
    HostStore::default()?.delete_folder(folder_id)
}

#[tauri::command]
pub fn create_host(parent_id: Option<String>, host: Host) -> Result<HostDocument> {
    HostStore::default()?.create_host(parent_id, host)
}

#[tauri::command]
pub fn update_host(host: Host) -> Result<HostDocument> {
    HostStore::default()?.update_host(host)
}

#[tauri::command]
pub fn delete_host(host_id: String) -> Result<HostDocument> {
    HostStore::default()?.delete_host(host_id)
}

#[tauri::command]
pub fn toggle_favorite(host_id: String) -> Result<HostDocument> {
    HostStore::default()?.toggle_favorite(host_id)
}

#[tauri::command]
pub fn duplicate_host(host_id: String, parent_id: Option<String>) -> Result<HostDocument> {
    HostStore::default()?.duplicate_host(host_id, parent_id)
}

#[tauri::command]
pub fn move_node(
    node_id: String,
    parent_id: Option<String>,
    index: Option<usize>,
) -> Result<HostDocument> {
    HostStore::default()?.move_node(node_id, parent_id, index)
}

#[tauri::command]
pub fn import_ssh_config_from_default() -> Result<HostDocument> {
    HostStore::default()?.import_ssh_config_from_default()
}

#[tauri::command]
pub fn export_config_bundle() -> Result<String> {
    crate::stores::export_config_bundle_to_default()
}

#[tauri::command]
pub fn import_config_bundle() -> Result<HostDocument> {
    crate::stores::import_config_bundle_from_default()
}

#[tauri::command]
pub fn validate_host_document(document: HostDocument) -> Vec<TreeValidationIssue> {
    document.validate()
}

#[tauri::command]
pub fn build_ssh_command(host_id: String) -> Result<SshCommand> {
    let document = HostStore::default()?.load()?;
    ssh::build_ssh_command(&document, &host_id)
}

#[tauri::command]
pub fn get_vault_document() -> Result<VaultDocument> {
    VaultStore::default()?.load()
}

#[tauri::command]
pub fn save_password(
    password_ref: String,
    username: String,
    password: String,
) -> Result<VaultDocument> {
    VaultStore::default()?.save_password(password_ref, username, password)
}

#[tauri::command]
pub fn delete_password(password_ref: String) -> Result<VaultDocument> {
    VaultStore::default()?.delete_password(password_ref)
}

#[tauri::command]
pub fn get_password_for_host(host_id: String) -> Result<Option<String>> {
    let hosts = HostStore::default()?.load()?;
    VaultStore::default()?.get_password_for_host(&hosts, &host_id)
}

#[tauri::command]
pub fn get_app_settings() -> Result<AppSettings> {
    SettingsStore::default()?.load()
}

#[tauri::command]
pub fn save_app_settings(settings: AppSettings) -> Result<AppSettings> {
    SettingsStore::default()?.replace(settings)
}
