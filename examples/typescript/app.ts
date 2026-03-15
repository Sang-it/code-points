import { EventEmitter } from "events";

class ConnectionPools {
  remove(id: string): void {
    this.connections.delete(id);
    activeCount--;
  }

  add(id: string): void {
    this.connections.set(id, "idle");
    activeCount++;
  }

  getActive(): string[] {
    return [...this.connections.entries()]
      .filter(([_, state]) => state === "active")
      .map(([id]) => id);
  }

  private connections: Map<string, ConnectionState> = new Map();
}

let activeCount = 0;

interface ServerConfig {
  host: string;
  port: number;
  debug?: boolean;
}

const MAX_CONNECTIONS = 100;

enum LogLevel {
  Debug = "DEBUG",
  Info = "INFO",
  Warn = "WARN",
  Error = "ERROR",
}

type ConnectionState = "idle" | "active" | "closed";

export const DEFAULT_CONFIG: ServerConfig = {
  host: "0.0.0.0",
  port: 8080,
};

function shutdown(pool: ConnectionPools): void {
  const active = pool.getActive();
  active.forEach((id) => pool.remove(id));
}

const parseConfig = (raw: Record<string, unknown>): ServerConfig => {
  return {
    host: String(raw.host ?? "localhost"),
    port: Number(raw.port ?? 3000),
    debug: Boolean(raw.debug),
  };
};

export function startServer(config: ServerConfig): void {
  const log = createLogger(LogLevel.Info);
  log(`Starting server on ${config.host}:${config.port}`);
}

function createLogger(level: LogLevel) {
  return (message: string) => {
    console.log(`[${level}] ${message}`);
  };
}
