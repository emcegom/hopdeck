use crate::{
    errors::Result,
    models::{Host, HostDocument, TreeValidationIssue},
    ssh::{self, SshCommand},
    stores::HostStore,
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
pub fn validate_host_document(document: HostDocument) -> Vec<TreeValidationIssue> {
    document.validate()
}

#[tauri::command]
pub fn build_ssh_command(host_id: String) -> Result<SshCommand> {
    let document = HostStore::default()?.load()?;
    ssh::build_ssh_command(&document, &host_id)
}
