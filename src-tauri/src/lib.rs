mod commands;
mod errors;
mod models;
mod ssh;
mod stores;
mod terminal;

pub fn run() {
    tauri::Builder::default()
        .manage(terminal::TerminalManager::default())
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
            commands::validate_host_document,
            commands::build_ssh_command,
            terminal::start_terminal_session,
            terminal::write_terminal_session,
            terminal::resize_terminal_session,
            terminal::close_terminal_session
        ])
        .run(tauri::generate_context!())
        .expect("failed to run Hopdeck");
}
