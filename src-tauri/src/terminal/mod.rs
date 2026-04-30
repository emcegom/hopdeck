use std::{
    collections::BTreeMap,
    io::{Read, Write},
    sync::Mutex,
    thread,
};

use portable_pty::{native_pty_system, Child, CommandBuilder, MasterPty, PtySize};
use serde::Serialize;
use tauri::{AppHandle, Emitter, State};
use uuid::Uuid;

use crate::{
    errors::{HopdeckError, Result},
    ssh,
    stores::HostStore,
};

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StartedTerminalSession {
    pub id: String,
    pub host_id: String,
    pub title: String,
    pub command: String,
    pub status: String,
    pub message: Option<String>,
    pub created_at: String,
}

#[derive(Default)]
pub struct TerminalManager {
    sessions: Mutex<BTreeMap<String, PtySession>>,
}

struct PtySession {
    master: Box<dyn MasterPty + Send>,
    writer: Box<dyn Write + Send>,
    child: Box<dyn Child + Send + Sync>,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct TerminalOutput {
    session_id: String,
    data: String,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct TerminalExit {
    session_id: String,
}

#[tauri::command]
pub fn start_terminal_session(
    app: AppHandle,
    state: State<'_, TerminalManager>,
    host_id: String,
) -> Result<StartedTerminalSession> {
    let document = HostStore::default()?.load()?;
    let host = document
        .hosts
        .get(&host_id)
        .ok_or_else(|| HopdeckError::HostNotFound(host_id.clone()))?;
    let resolved = ssh::build_ssh_command(&document, &host_id)?;
    let session_id = format!("session-{}", Uuid::new_v4());

    let pty_system = native_pty_system();
    let pair = pty_system
        .openpty(PtySize {
            rows: 28,
            cols: 100,
            pixel_width: 0,
            pixel_height: 0,
        })
        .map_err(terminal_error)?;

    let mut command = CommandBuilder::new("ssh");
    for arg in &resolved.argv {
        command.arg(arg);
    }

    let child = pair.slave.spawn_command(command).map_err(terminal_error)?;
    let reader = pair.master.try_clone_reader().map_err(terminal_error)?;
    let writer = pair.master.take_writer().map_err(terminal_error)?;
    drop(pair.slave);

    state
        .sessions
        .lock()
        .map_err(|_| HopdeckError::Terminal("terminal session registry is poisoned".to_string()))?
        .insert(
            session_id.clone(),
            PtySession {
                master: pair.master,
                writer,
                child,
            },
        );

    spawn_output_reader(app, session_id.clone(), reader);

    Ok(StartedTerminalSession {
        id: session_id,
        host_id,
        title: host.alias.clone(),
        command: resolved.command,
        status: "running".to_string(),
        message: if resolved.jumps.is_empty() {
            None
        } else {
            Some(format!(
                "Via {} to {}",
                resolved.jumps.join(" -> "),
                resolved.target
            ))
        },
        created_at: chrono::Utc::now().to_rfc3339(),
    })
}

#[tauri::command]
pub fn write_terminal_session(
    state: State<'_, TerminalManager>,
    session_id: String,
    data: String,
) -> Result<()> {
    let mut sessions = state
        .sessions
        .lock()
        .map_err(|_| HopdeckError::Terminal("terminal session registry is poisoned".to_string()))?;
    let session = sessions.get_mut(&session_id).ok_or_else(|| {
        HopdeckError::InvalidRequest(format!("terminal session not found: {session_id}"))
    })?;

    session
        .writer
        .write_all(data.as_bytes())
        .map_err(terminal_error)?;
    session.writer.flush().map_err(terminal_error)?;
    Ok(())
}

#[tauri::command]
pub fn resize_terminal_session(
    state: State<'_, TerminalManager>,
    session_id: String,
    rows: u16,
    cols: u16,
) -> Result<()> {
    let sessions = state
        .sessions
        .lock()
        .map_err(|_| HopdeckError::Terminal("terminal session registry is poisoned".to_string()))?;
    let session = sessions.get(&session_id).ok_or_else(|| {
        HopdeckError::InvalidRequest(format!("terminal session not found: {session_id}"))
    })?;

    session
        .master
        .resize(PtySize {
            rows,
            cols,
            pixel_width: 0,
            pixel_height: 0,
        })
        .map_err(terminal_error)?;
    Ok(())
}

#[tauri::command]
pub fn close_terminal_session(state: State<'_, TerminalManager>, session_id: String) -> Result<()> {
    let mut sessions = state
        .sessions
        .lock()
        .map_err(|_| HopdeckError::Terminal("terminal session registry is poisoned".to_string()))?;

    if let Some(mut session) = sessions.remove(&session_id) {
        let _ = session.child.kill();
    }

    Ok(())
}

fn spawn_output_reader(app: AppHandle, session_id: String, mut reader: Box<dyn Read + Send>) {
    thread::spawn(move || {
        let mut buffer = [0_u8; 8192];

        loop {
            match reader.read(&mut buffer) {
                Ok(0) => break,
                Ok(size) => {
                    let data = String::from_utf8_lossy(&buffer[..size]).to_string();
                    let _ = app.emit(
                        "terminal-output",
                        TerminalOutput {
                            session_id: session_id.clone(),
                            data,
                        },
                    );
                }
                Err(error) => {
                    let _ = app.emit(
                        "terminal-output",
                        TerminalOutput {
                            session_id: session_id.clone(),
                            data: format!("\r\n[hopdeck] terminal read error: {error}\r\n"),
                        },
                    );
                    break;
                }
            }
        }

        let _ = app.emit("terminal-exit", TerminalExit { session_id });
    });
}

fn terminal_error(error: impl ToString) -> HopdeckError {
    HopdeckError::Terminal(error.to_string())
}
