use std::{
    collections::BTreeMap,
    io::{Read, Write},
    sync::{Arc, Mutex},
    thread,
};

use portable_pty::{native_pty_system, Child, CommandBuilder, MasterPty, PtySize};
use serde::Serialize;
use tauri::{AppHandle, Emitter, State};
use uuid::Uuid;

use crate::{
    errors::{HopdeckError, Result},
    models::HostAuth,
    ssh,
    stores::{HostStore, VaultStore},
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
    writer: Arc<Mutex<Box<dyn Write + Send>>>,
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
    let auto_login_password = match &host.auth {
        HostAuth::Password {
            password_ref: Some(password_ref),
            auto_login: true,
        } => VaultStore::default()?.password_for_ref(password_ref)?,
        _ => None,
    };

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
    let writer = Arc::new(Mutex::new(
        pair.master.take_writer().map_err(terminal_error)?,
    ));
    drop(pair.slave);

    state
        .sessions
        .lock()
        .map_err(|_| HopdeckError::Terminal("terminal session registry is poisoned".to_string()))?
        .insert(
            session_id.clone(),
            PtySession {
                master: pair.master,
                writer: Arc::clone(&writer),
                child,
            },
        );

    spawn_output_reader(app, session_id.clone(), reader, writer, auto_login_password);

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

    let mut writer = session
        .writer
        .lock()
        .map_err(|_| HopdeckError::Terminal("terminal writer is poisoned".to_string()))?;
    writer.write_all(data.as_bytes()).map_err(terminal_error)?;
    writer.flush().map_err(terminal_error)?;
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

fn spawn_output_reader(
    app: AppHandle,
    session_id: String,
    mut reader: Box<dyn Read + Send>,
    writer: Arc<Mutex<Box<dyn Write + Send>>>,
    auto_login_password: Option<String>,
) {
    thread::spawn(move || {
        let mut buffer = [0_u8; 8192];
        let mut auto_login = auto_login_password.map(AutoLogin::new);

        loop {
            match reader.read(&mut buffer) {
                Ok(0) => break,
                Ok(size) => {
                    let data = String::from_utf8_lossy(&buffer[..size]).to_string();
                    if let Some(auto_login) = auto_login.as_mut() {
                        if auto_login.should_write_password(&data) {
                            if let Ok(mut writer) = writer.lock() {
                                let _ = writer.write_all(auto_login.password_input().as_bytes());
                                let _ = writer.flush();
                            }
                        }
                    }

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

struct AutoLogin {
    password: String,
    detector: PromptDetector,
    has_written: bool,
}

impl AutoLogin {
    fn new(password: String) -> Self {
        Self {
            password,
            detector: PromptDetector::default(),
            has_written: false,
        }
    }

    fn should_write_password(&mut self, data: &str) -> bool {
        if self.has_written {
            return false;
        }

        if self.detector.push_and_detect(data) {
            self.has_written = true;
            return true;
        }

        false
    }

    fn password_input(&self) -> String {
        format!("{}\n", self.password)
    }
}

#[derive(Default)]
struct PromptDetector {
    recent: String,
}

impl PromptDetector {
    fn push_and_detect(&mut self, data: &str) -> bool {
        self.recent.push_str(data);
        if self.recent.len() > 512 {
            self.recent = self
                .recent
                .chars()
                .rev()
                .take(512)
                .collect::<Vec<_>>()
                .into_iter()
                .rev()
                .collect();
        }

        is_password_prompt(&self.recent)
    }
}

fn is_password_prompt(value: &str) -> bool {
    let normalized = strip_ansi(value).to_ascii_lowercase();
    let Some(keyword_index) = normalized
        .rfind("password")
        .or_else(|| normalized.rfind("passphrase"))
    else {
        return false;
    };
    let prompt_tail = normalized[keyword_index..].trim_end();

    !prompt_tail.contains('\n')
        && !prompt_tail.contains('\r')
        && (prompt_tail.ends_with(':') || prompt_tail.ends_with("?"))
}

fn strip_ansi(value: &str) -> String {
    let mut output = String::with_capacity(value.len());
    let mut chars = value.chars().peekable();

    while let Some(ch) = chars.next() {
        if ch == '\x1b' && chars.peek() == Some(&'[') {
            chars.next();
            for next in chars.by_ref() {
                if next.is_ascii_alphabetic() {
                    break;
                }
            }
        } else {
            output.push(ch);
        }
    }

    output
}

#[cfg(test)]
mod tests {
    use super::{AutoLogin, PromptDetector};

    #[test]
    fn detects_password_prompt_across_chunks() {
        let mut detector = PromptDetector::default();

        assert!(!detector.push_and_detect("app@host's pass"));
        assert!(detector.push_and_detect("word:"));
    }

    #[test]
    fn detects_key_passphrase_prompt() {
        let mut detector = PromptDetector::default();

        assert!(detector.push_and_detect("Enter passphrase for key '/Users/zane/.ssh/id_ed25519':"));
    }

    #[test]
    fn ignores_non_prompt_password_text() {
        let mut detector = PromptDetector::default();

        assert!(!detector.push_and_detect("Permission denied, please try again.\r\n"));
        assert!(!detector.push_and_detect("Password authentication failed\r\n"));
    }

    #[test]
    fn auto_login_writes_only_once() {
        let mut auto_login = AutoLogin::new("secret".to_string());

        assert!(auto_login.should_write_password("Password:"));
        assert_eq!(auto_login.password_input(), "secret\n");
        assert!(!auto_login.should_write_password("Password:"));
    }
}
