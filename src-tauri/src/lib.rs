mod commands;
mod errors;
mod models;
mod ssh;
mod stores;
mod terminal;

use tauri::{ActivationPolicy, Emitter, Manager, RunEvent, Theme};

const CLOSE_ACTIVE_SESSION_MENU_ID: &str = "close-active-session";
const CLOSE_ACTIVE_SESSION_EVENT: &str = "hopdeck-close-active-session";

pub fn run() {
    let app = tauri::Builder::default()
        .manage(terminal::TerminalManager::default())
        .plugin(tauri_plugin_clipboard_manager::init())
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .setup(|app| {
            app.set_activation_policy(ActivationPolicy::Regular);
            app.set_menu(build_app_menu(app)?)?;
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.set_theme(Some(Theme::Light));
                set_native_window_background(&window);
                focus_main_window(&window);
            }

            Ok(())
        })
        .on_menu_event(|app, event| {
            if event.id() == CLOSE_ACTIVE_SESSION_MENU_ID {
                let _ = app.emit(CLOSE_ACTIVE_SESSION_EVENT, ());
            }
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

#[cfg(target_os = "macos")]
fn set_native_window_background(window: &tauri::WebviewWindow) {
    use objc2_app_kit::{NSColor, NSWindow};

    if let Ok(ns_window) = window.ns_window() {
        unsafe {
            let ns_window = &*ns_window.cast::<NSWindow>();
            let bg_color = NSColor::colorWithDeviceRed_green_blue_alpha(
                248.0 / 255.0,
                251.0 / 255.0,
                253.0 / 255.0,
                1.0,
            );
            ns_window.setBackgroundColor(Some(&bg_color));
        }
    }
}

#[cfg(not(target_os = "macos"))]
fn set_native_window_background(_window: &tauri::WebviewWindow) {}

fn build_app_menu(app: &tauri::App) -> tauri::Result<tauri::menu::Menu<tauri::Wry>> {
    use tauri::menu::{AboutMetadata, Menu, MenuItem, PredefinedMenuItem, Submenu};

    let package_info = app.package_info();
    let about_metadata = AboutMetadata {
        name: Some(package_info.name.clone()),
        version: Some(package_info.version.to_string()),
        copyright: app.config().bundle.copyright.clone(),
        authors: app.config().bundle.publisher.clone().map(|publisher| vec![publisher]),
        ..Default::default()
    };

    let app_menu = Submenu::with_items(
        app,
        package_info.name.clone(),
        true,
        &[
            &PredefinedMenuItem::about(app, None, Some(about_metadata))?,
            &PredefinedMenuItem::separator(app)?,
            &PredefinedMenuItem::services(app, None)?,
            &PredefinedMenuItem::separator(app)?,
            &PredefinedMenuItem::hide(app, None)?,
            &PredefinedMenuItem::hide_others(app, None)?,
            &PredefinedMenuItem::separator(app)?,
            &PredefinedMenuItem::quit(app, None)?,
        ],
    )?;
    let file_menu = Submenu::with_items(
        app,
        "File",
        true,
        &[&MenuItem::with_id(
            app,
            CLOSE_ACTIVE_SESSION_MENU_ID,
            "Close Terminal",
            true,
            Some("CmdOrCtrl+W"),
        )?],
    )?;
    let edit_menu = Submenu::with_items(
        app,
        "Edit",
        true,
        &[
            &PredefinedMenuItem::undo(app, None)?,
            &PredefinedMenuItem::redo(app, None)?,
            &PredefinedMenuItem::separator(app)?,
            &PredefinedMenuItem::cut(app, None)?,
            &PredefinedMenuItem::copy(app, None)?,
            &PredefinedMenuItem::paste(app, None)?,
            &PredefinedMenuItem::select_all(app, None)?,
        ],
    )?;
    let view_menu = Submenu::with_items(
        app,
        "View",
        true,
        &[&PredefinedMenuItem::fullscreen(app, None)?],
    )?;
    let window_menu = Submenu::with_items(
        app,
        "Window",
        true,
        &[
            &PredefinedMenuItem::minimize(app, None)?,
            &PredefinedMenuItem::maximize(app, None)?,
        ],
    )?;
    let help_menu = Submenu::with_items(app, "Help", true, &[])?;

    Menu::with_items(
        app,
        &[&app_menu, &file_menu, &edit_menu, &view_menu, &window_menu, &help_menu],
    )
}
