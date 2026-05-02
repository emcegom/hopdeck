# Terminal Interaction Design

Hopdeck treats the embedded terminal as a product-critical surface. A session is
not considered usable because an `ssh` process exists; it is usable only when
the right-side terminal accepts input, streams output, survives tab switches and
resizes, and closes only when the user closes it.

## Architecture

Hopdeck uses `xterm.js` for rendering and keyboard capture, Rust
`portable-pty` for the local pseudoterminal, and the system OpenSSH client for
connection execution.

The lifecycle owner is the Rust `TerminalManager`:

- `start_terminal_session` creates the PTY, starts OpenSSH, starts the reader
  thread, and returns session metadata.
- `write_terminal_session` writes raw xterm input bytes to the PTY.
- `resize_terminal_session` forwards visible terminal dimensions to the PTY.
- `close_terminal_session` is destructive and is called only for an explicit
  user close or host/folder deletion.
- `read_terminal_session_output` replays buffered output chunks after a sequence
  number.

The React terminal pane is an attachment, not the owner of the SSH process:

- Mounting creates an xterm instance and attaches it to an existing backend
  session.
- Unmounting disposes xterm listeners and DOM resources only.
- Component cleanup must never kill the backend SSH process.
- Live output and replay output both use sequence numbers so reconnects and
  remounts do not duplicate text.

## Authentication

The default mode is interactive terminal first. Saved passwords are an
auto-login convenience written into the PTY when a password-like prompt is
detected. The app must not force a non-interactive askpass path that prevents
manual typing from working.

OpenSSH remains the preferred first backend because it preserves system SSH
behavior: `~/.ssh/config`, `known_hosts`, SSH agent, certificates, jump options,
and platform updates. A future embedded SSH backend can be evaluated if Hopdeck
needs structured authentication UI or protocol-level session control.

## Review Findings Applied

The design was reviewed from three roles:

- Terminal architecture: backend session lifecycle must be independent from
  React component lifecycle.
- SSH/Auth: OpenSSH is a reasonable backend, but askpass forcing must not block
  manual fallback.
- Product QA: passing means real terminal interaction, not just an active SSH
  process.

## Acceptance

P0 acceptance requires all of these to pass:

- Double-clicking a host opens a tab and the terminal receives keyboard input.
- `whoami`, `pwd`, `echo hopdeck-ok`, `hostname`, `Ctrl-C`, and paste work in
  the right-side terminal.
- Prompt, banner, command output, and errors are visible without switching tabs.
- Window resize keeps the terminal usable.
- Switching tabs or changing visual settings does not kill the backend session.
- Closing a tab kills the backend child process.
- Docker direct SSH reaches the target container and remains interactive.
- Docker jump SSH reaches the final target container, not merely the jump host.
- DNS, port, authentication, and jump failures produce visible terminal output.

Anything less is not considered a usable terminal.
