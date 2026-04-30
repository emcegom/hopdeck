use crate::errors::{HopdeckError, Result};
use crate::models::{Host, HostDocument};

#[derive(Debug, Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ResolvedSshCommand {
    pub command: String,
    pub target: String,
    pub jumps: Vec<String>,
    pub argv: Vec<String>,
}

pub type SshCommand = ResolvedSshCommand;

pub fn build_ssh_command(document: &HostDocument, host_id: &str) -> Result<ResolvedSshCommand> {
    let host = document
        .hosts
        .get(host_id)
        .ok_or_else(|| HopdeckError::HostNotFound(host_id.to_string()))?;

    let jumps = host
        .jump_chain
        .iter()
        .map(|jump_id| {
            let jump = document
                .hosts
                .get(jump_id)
                .ok_or_else(|| HopdeckError::HostNotFound(jump_id.clone()))?;
            Ok(host_spec(jump, true))
        })
        .collect::<Result<Vec<_>>>()?;

    let target = host_spec(host, false);
    let mut argv = Vec::new();

    if !jumps.is_empty() {
        argv.push("-J".to_string());
        argv.push(jumps.join(","));
    }

    argv.push(target.clone());
    argv.push("-p".to_string());
    argv.push(host.port.to_string());
    let command = shell_join("ssh", &argv);

    Ok(ResolvedSshCommand {
        command,
        target,
        jumps,
        argv,
    })
}

fn host_spec(host: &Host, include_port: bool) -> String {
    if include_port {
        format!("{}@{}:{}", host.user, host.host, host.port)
    } else {
        format!("{}@{}", host.user, host.host)
    }
}

fn shell_escape(value: &str) -> String {
    if !value.is_empty()
        && value
            .chars()
            .all(|ch| ch.is_ascii_alphanumeric() || "-_./=+".contains(ch))
    {
        return value.to_string();
    }

    format!("'{}'", value.replace('\'', "'\\''"))
}

fn shell_join(program: &str, argv: &[String]) -> String {
    std::iter::once(program.to_string())
        .chain(argv.iter().map(|arg| shell_escape(arg)))
        .collect::<Vec<_>>()
        .join(" ")
}

#[cfg(test)]
mod tests {
    use crate::models::HostDocument;

    use super::build_ssh_command;

    #[test]
    fn builds_jump_command() {
        let document = HostDocument::sample();
        let resolved = build_ssh_command(&document, "prod-app-01").unwrap();

        assert_eq!(
            resolved.command,
            "ssh -J 'zane@1.2.3.4:22' 'app@10.0.1.20' -p 22"
        );
    }
}
