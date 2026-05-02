export type HostAuth =
  | { type: "password"; passwordRef?: string | null; autoLogin: boolean }
  | { type: "key"; identityFile?: string | null; useAgent: boolean }
  | { type: "agent" }
  | { type: "none" };

export interface Host {
  id: string;
  alias: string;
  host: string;
  user: string;
  port: number;
  tags: string[];
  favorite: boolean;
  isJumpHost: boolean;
  jumpChain: string[];
  auth: HostAuth;
  notes: string;
  createdAt?: string | null;
  updatedAt?: string | null;
  lastConnectedAt?: string | null;
}

export type TreeNode =
  | {
      type: "folder";
      id: string;
      name: string;
      expanded: boolean;
      children: TreeNode[];
    }
  | {
      type: "hostRef";
      id: string;
      hostId: string;
    };

export interface HostDocument {
  version: number;
  tree: TreeNode[];
  hosts: Record<string, Host>;
}

export interface ResolvedSshCommand {
  command: string;
  target: string;
  jumps: string[];
  argv: string[];
}

export interface TerminalSession {
  id: string;
  hostId: string;
  title: string;
  command: string;
  status: "starting" | "running" | "closed" | "error";
  message?: string;
  createdAt: string;
}

export interface TerminalOutputEvent {
  sessionId: string;
  seq: number;
  data: string;
}

export interface TerminalOutputChunk {
  seq: number;
  data: string;
}

export interface TerminalExitEvent {
  sessionId: string;
}

export interface VaultItem {
  username: string;
  password: string;
}

export interface VaultDocument {
  version: number;
  mode: "plain";
  items: Record<string, VaultItem>;
}

export interface AppSettings {
  version: number;
  theme: "system" | "light" | "dark";
  terminal: {
    fontFamily: string;
    fontSize: number;
    cursorStyle: string;
    backgroundBlur: number;
    backgroundOpacity: number;
    autoCopySelection: boolean;
    colors: {
      background: string;
      foreground: string;
      cursor: string;
      selection: string;
      ansi: string[];
    };
  };
  vault: {
    mode: string;
    clearClipboardAfterSeconds: number;
  };
  connection: {
    defaultOpenMode: string;
    autoLogin: boolean;
    closeTabOnDisconnect: boolean;
  };
}

export const describeAuth = (auth: HostAuth): string => {
  switch (auth.type) {
    case "password":
      return auth.autoLogin ? "Password with auto-login" : "Password";
    case "key":
      return auth.useAgent ? "SSH key via agent" : "SSH key";
    case "agent":
      return "SSH agent";
    case "none":
      return "No auth";
  }
};

export const displayHost = (host: Host): string => {
  const target = host.user ? `${host.user}@${host.host}` : host.host;
  return `${target}:${host.port}`;
};
