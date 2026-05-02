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

    let jump_hosts = host
        .jump_chain
        .iter()
        .map(|jump_id| {
            document
                .hosts
                .get(jump_id)
                .ok_or_else(|| HopdeckError::HostNotFound(jump_id.clone()))
        })
        .collect::<Result<Vec<_>>>()?;
    let jumps = jump_hosts
        .iter()
        .map(|jump| host_spec(jump, true))
        .collect::<Vec<_>>();

    let target = host_spec(host, false);
    let mut argv = Vec::new();

    argv.push("-o".to_string());
    argv.push("StrictHostKeyChecking=accept-new".to_string());
    argv.push("-o".to_string());
    argv.push("ConnectTimeout=10".to_string());
    argv.push("-tt".to_string());

    if let Some(proxy_command) = proxy_command(&jump_hosts) {
        argv.push("-o".to_string());
        argv.push(format!("ProxyCommand={proxy_command}"));
    }

    argv.push("-p".to_string());
    argv.push(host.port.to_string());
    argv.push(target.clone());
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

fn proxy_command(jump_hosts: &[&Host]) -> Option<String> {
    let jump = jump_hosts.last()?;
    let mut argv = Vec::new();

    argv.push("-o".to_string());
    argv.push("StrictHostKeyChecking=accept-new".to_string());
    argv.push("-o".to_string());
    argv.push("ConnectTimeout=10".to_string());

    if jump_hosts.len() > 1 {
        let prior_jumps = jump_hosts[..jump_hosts.len() - 1]
            .iter()
            .map(|prior_jump| host_spec(prior_jump, true))
            .collect::<Vec<_>>();
        argv.push("-J".to_string());
        argv.push(prior_jumps.join(","));
    }

    argv.push("-p".to_string());
    argv.push(jump.port.to_string());
    argv.push("-W".to_string());
    argv.push("%h:%p".to_string());
    argv.push(host_spec(jump, false));

    shell_join("ssh", &argv)
        .strip_prefix("ssh ")
        .map(|args| format!("ssh {args}"))
}

fn shell_escape(value: &str) -> String {
    if !value.is_empty()
        && value
            .chars()
            .all(|ch| ch.is_ascii_alphanumeric() || "-_./=+@%:".contains(ch))
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
            "ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -tt -o 'ProxyCommand=ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -p 22 -W %h:%p zane@1.2.3.4' -p 22 app@10.0.1.20"
        );
    }

    #[test]
    fn places_target_port_before_destination() {
        let document = HostDocument::sample();
        let resolved = build_ssh_command(&document, "jump-prod").unwrap();

        assert_eq!(
            resolved.argv,
            vec![
                "-o",
                "StrictHostKeyChecking=accept-new",
                "-o",
                "ConnectTimeout=10",
                "-tt",
                "-p",
                "22",
                "zane@1.2.3.4"
            ]
        );
        assert_eq!(
            resolved.command,
            "ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -tt -p 22 zane@1.2.3.4"
        );
    }
}
