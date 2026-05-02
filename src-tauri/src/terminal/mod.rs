use std::{
    collections::BTreeMap,
    collections::VecDeque,
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
    output: Arc<Mutex<TerminalOutputBuffer>>,
    child: Box<dyn Child + Send + Sync>,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct TerminalOutput {
    session_id: String,
    seq: u64,
    data: String,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TerminalOutputChunk {
    seq: u64,
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
    let auto_login_passwords = auto_login_passwords_for_chain(&document, &host_id)?;

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
    command.env("TERM", "xterm-256color");
    command.env("COLORTERM", "truecolor");
    remove_locale_env(&mut command);
    for arg in &resolved.argv {
        command.arg(arg);
    }

    let child = pair.slave.spawn_command(command).map_err(terminal_error)?;
    let reader = pair.master.try_clone_reader().map_err(terminal_error)?;
    let writer = Arc::new(Mutex::new(
        pair.master.take_writer().map_err(terminal_error)?,
    ));
    let output = Arc::new(Mutex::new(TerminalOutputBuffer::default()));
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
                output: Arc::clone(&output),
                child,
            },
        );

    spawn_output_reader(
        app,
        session_id.clone(),
        reader,
        writer,
        output,
        auto_login_passwords,
    );

    Ok(StartedTerminalSession {
        id: session_id,
        host_id,
        title: host.alias.clone(),
        command: resolved.command,
        status: "running".to_string(),
        message: Some(if resolved.jumps.is_empty() {
            format!("Connecting to {}", resolved.target)
        } else {
            format!("Via {} to {}", resolved.jumps.join(" -> "), resolved.target)
        }),
        created_at: chrono::Utc::now().to_rfc3339(),
    })
}

fn remove_locale_env(command: &mut CommandBuilder) {
    for key in [
        "LANG",
        "LC_ALL",
        "LC_COLLATE",
        "LC_CTYPE",
        "LC_MESSAGES",
        "LC_MONETARY",
        "LC_NUMERIC",
        "LC_TIME",
    ] {
        command.env_remove(key);
    }
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
pub fn read_terminal_session_output(
    state: State<'_, TerminalManager>,
    session_id: String,
    after_seq: Option<u64>,
) -> Result<Vec<TerminalOutputChunk>> {
    let sessions = state
        .sessions
        .lock()
        .map_err(|_| HopdeckError::Terminal("terminal session registry is poisoned".to_string()))?;
    let session = sessions.get(&session_id).ok_or_else(|| {
        HopdeckError::InvalidRequest(format!("terminal session not found: {session_id}"))
    })?;
    let output = session
        .output
        .lock()
        .map_err(|_| HopdeckError::Terminal("terminal output buffer is poisoned".to_string()))?;

    Ok(output.chunks_after(after_seq.unwrap_or(0)))
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
    output: Arc<Mutex<TerminalOutputBuffer>>,
    auto_login_passwords: Vec<String>,
) {
    thread::spawn(move || {
        let mut buffer = [0_u8; 8192];
        let mut auto_login = AutoLogin::new(auto_login_passwords);

        loop {
            match reader.read(&mut buffer) {
                Ok(0) => break,
                Ok(size) => {
                    let data = String::from_utf8_lossy(&buffer[..size]).to_string();
                    let seq = remember_terminal_output(&output, &data);
                    let auto_input = auto_login.input_for_prompt(&data);

                    let _ = app.emit(
                        "terminal-output",
                        TerminalOutput {
                            session_id: session_id.clone(),
                            seq,
                            data,
                        },
                    );

                    if let Some(input) = auto_input {
                        if let Ok(mut writer) = writer.lock() {
                            let _ = writer.write_all(input.as_bytes());
                            let _ = writer.flush();
                        }
                    }
                }
                Err(error) => {
                    let data = format!("\r\n[hopdeck] terminal read error: {error}\r\n");
                    let seq = remember_terminal_output(&output, &data);
                    let _ = app.emit(
                        "terminal-output",
                        TerminalOutput {
                            session_id: session_id.clone(),
                            seq,
                            data,
                        },
                    );
                    break;
                }
            }
        }

        let _ = app.emit("terminal-exit", TerminalExit { session_id });
    });
}

#[derive(Default)]
struct TerminalOutputBuffer {
    next_seq: u64,
    chunks: VecDeque<TerminalOutputChunk>,
    bytes: usize,
}

impl TerminalOutputBuffer {
    fn push(&mut self, data: String) -> u64 {
        const MAX_OUTPUT_BYTES: usize = 64 * 1024;

        self.next_seq += 1;
        let seq = self.next_seq;
        self.bytes += data.len();
        self.chunks.push_back(TerminalOutputChunk { seq, data });

        while self.bytes > MAX_OUTPUT_BYTES {
            let Some(chunk) = self.chunks.pop_front() else {
                break;
            };
            self.bytes = self.bytes.saturating_sub(chunk.data.len());
        }

        seq
    }

    fn chunks_after(&self, after_seq: u64) -> Vec<TerminalOutputChunk> {
        self.chunks
            .iter()
            .filter(|chunk| chunk.seq > after_seq)
            .cloned()
            .collect()
    }
}

fn remember_terminal_output(output: &Arc<Mutex<TerminalOutputBuffer>>, data: &str) -> u64 {
    match output.lock() {
        Ok(mut output) => output.push(data.to_string()),
        Err(_) => 0,
    }
}

fn terminal_error(error: impl ToString) -> HopdeckError {
    HopdeckError::Terminal(error.to_string())
}

fn auto_login_passwords_for_chain(
    document: &crate::models::HostDocument,
    host_id: &str,
) -> Result<Vec<String>> {
    let host = document
        .hosts
        .get(host_id)
        .ok_or_else(|| HopdeckError::HostNotFound(host_id.to_string()))?;
    let vault = VaultStore::default()?;
    let mut passwords = Vec::new();

    for chain_host_id in host.jump_chain.iter().chain(std::iter::once(&host.id)) {
        let chain_host = document
            .hosts
            .get(chain_host_id)
            .ok_or_else(|| HopdeckError::HostNotFound(chain_host_id.clone()))?;

        let HostAuth::Password {
            password_ref: Some(password_ref),
            auto_login: true,
        } = &chain_host.auth
        else {
            continue;
        };

        if let Some(password) = vault.password_for_ref(password_ref)? {
            passwords.push(password);
        }
    }

    Ok(passwords)
}

struct AutoLogin {
    passwords: VecDeque<String>,
    detector: PromptDetector,
}

impl AutoLogin {
    fn new(passwords: Vec<String>) -> Self {
        Self {
            passwords: passwords.into(),
            detector: PromptDetector::default(),
        }
    }

    fn input_for_prompt(&mut self, data: &str) -> Option<String> {
        match self.detector.push_and_detect(data) {
            Some(PromptKind::HostKeyConfirmation) => Some("yes\n".to_string()),
            Some(PromptKind::Password) => self
                .passwords
                .pop_front()
                .map(|password| format!("{password}\n")),
            None => None,
        }
    }
}

#[derive(Default)]
struct PromptDetector {
    recent: String,
}

enum PromptKind {
    HostKeyConfirmation,
    Password,
}

impl PromptDetector {
    fn push_and_detect(&mut self, data: &str) -> Option<PromptKind> {
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

        if is_host_key_confirmation_prompt(&self.recent) {
            self.recent.clear();
            return Some(PromptKind::HostKeyConfirmation);
        }

        if is_password_prompt(&self.recent) {
            self.recent.clear();
            return Some(PromptKind::Password);
        }

        None
    }
}

fn is_host_key_confirmation_prompt(value: &str) -> bool {
    let normalized = strip_ansi(value).to_ascii_lowercase();
    let prompt_tail = normalized.trim_end();

    prompt_tail.contains("are you sure you want to continue connecting")
        && prompt_tail.contains("yes/no")
        && !prompt_tail.contains('\n')
        && !prompt_tail.contains('\r')
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
    use super::{AutoLogin, PromptDetector, PromptKind, TerminalOutputBuffer};

    #[test]
    fn detects_password_prompt_across_chunks() {
        let mut detector = PromptDetector::default();

        assert!(detector.push_and_detect("app@host's pass").is_none());
        assert!(matches!(
            detector.push_and_detect("word:"),
            Some(PromptKind::Password)
        ));
    }

    #[test]
    fn detects_key_passphrase_prompt() {
        let mut detector = PromptDetector::default();

        assert!(matches!(
            detector.push_and_detect("Enter passphrase for key '/Users/zane/.ssh/id_ed25519':"),
            Some(PromptKind::Password)
        ));
    }

    #[test]
    fn ignores_non_prompt_password_text() {
        let mut detector = PromptDetector::default();

        assert!(detector
            .push_and_detect("Permission denied, please try again.\r\n")
            .is_none());
        assert!(detector
            .push_and_detect("Password authentication failed\r\n")
            .is_none());
    }

    #[test]
    fn detects_host_key_confirmation_prompt() {
        let mut detector = PromptDetector::default();

        assert!(matches!(
            detector.push_and_detect(
                "Are you sure you want to continue connecting (yes/no/[fingerprint])?"
            ),
            Some(PromptKind::HostKeyConfirmation)
        ));
    }

    #[test]
    fn auto_login_writes_only_once() {
        let mut auto_login = AutoLogin::new(vec!["secret".to_string()]);

        assert_eq!(
            auto_login.input_for_prompt("Password:"),
            Some("secret\n".to_string())
        );
        assert_eq!(auto_login.input_for_prompt("Password:"), None);
    }

    #[test]
    fn auto_login_writes_jump_chain_passwords_in_order() {
        let mut auto_login =
            AutoLogin::new(vec!["jump-secret".to_string(), "target-secret".to_string()]);

        assert_eq!(
            auto_login.input_for_prompt("hop@127.0.0.1's password:"),
            Some("jump-secret\n".to_string())
        );
        assert_eq!(
            auto_login.input_for_prompt("\r\nhop@target's password:"),
            Some("target-secret\n".to_string())
        );
        assert_eq!(
            auto_login.input_for_prompt("\r\nhop@target's password:"),
            None
        );
    }

    #[test]
    fn auto_login_confirms_new_host_key_before_passwords() {
        let mut auto_login = AutoLogin::new(vec!["secret".to_string()]);

        assert_eq!(
            auto_login.input_for_prompt(
                "Are you sure you want to continue connecting (yes/no/[fingerprint])?"
            ),
            Some("yes\n".to_string())
        );
        assert_eq!(
            auto_login.input_for_prompt("hop@host's password:"),
            Some("secret\n".to_string())
        );
    }

    #[test]
    fn output_buffer_replays_chunks_after_sequence() {
        let mut buffer = TerminalOutputBuffer::default();

        assert_eq!(buffer.push("first".to_string()), 1);
        assert_eq!(buffer.push("second".to_string()), 2);

        let chunks = buffer.chunks_after(1);
        assert_eq!(chunks.len(), 1);
        assert_eq!(chunks[0].seq, 2);
        assert_eq!(chunks[0].data, "second");
    }
}
