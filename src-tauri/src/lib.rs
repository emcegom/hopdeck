mod commands;
mod errors;
mod models;
mod ssh;
mod stores;
mod terminal;

use tauri::{ActivationPolicy, Manager, RunEvent};

pub fn run() {
    let app = tauri::Builder::default()
        .manage(terminal::TerminalManager::default())
        .plugin(tauri_plugin_clipboard_manager::init())
        .setup(|app| {
            app.set_activation_policy(ActivationPolicy::Regular);
            if let Some(window) = app.get_webview_window("main") {
                focus_main_window(&window);
            }

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::get_host_document,
            commands::save_host_document,
            commands::create_folder,
            commands::update_folder,
            commands::delete_folder,
            commands::create_host,
            commands::update_host,
            commands::delete_host,
            commands::toggle_favorite,
            commands::duplicate_host,
            commands::move_node,
            commands::import_ssh_config_from_default,
            commands::export_config_bundle,
            commands::import_config_bundle,
            commands::validate_host_document,
            commands::build_ssh_command,
            commands::get_vault_document,
            commands::save_password,
            commands::delete_password,
            commands::get_password_for_host,
            commands::get_app_settings,
            commands::save_app_settings,
            commands::import_iterm2_theme,
            terminal::start_terminal_session,
            terminal::write_terminal_session,
            terminal::read_terminal_session_output,
            terminal::resize_terminal_session,
            terminal::close_terminal_session
        ])
        .build(tauri::generate_context!())
        .expect("failed to build Hopdeck");

    app.run(|app, event| {
        if let RunEvent::Reopen { .. } = event {
            if let Some(window) = app.get_webview_window("main") {
                focus_main_window(&window);
            }
        }
    });
}

fn focus_main_window(window: &tauri::WebviewWindow) {
    let _ = window.set_focusable(true);
    let _ = window.unminimize();
    let _ = window.show();
    let _ = window.center();
    let _ = window.set_focus();
}
