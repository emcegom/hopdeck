use thiserror::Error;

#[derive(Debug, Error)]
pub enum HopdeckError {
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),
    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),
    #[error("data directory is unavailable")]
    DataDirectoryUnavailable,
    #[error("host not found: {0}")]
    HostNotFound(String),
    #[error("tree node not found: {0}")]
    TreeNodeNotFound(String),
    #[error("invalid request: {0}")]
    InvalidRequest(String),
    #[error("terminal error: {0}")]
    Terminal(String),
}

pub type Result<T> = std::result::Result<T, HopdeckError>;

impl serde::Serialize for HopdeckError {
    fn serialize<S>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        serializer.serialize_str(&self.to_string())
    }
}
