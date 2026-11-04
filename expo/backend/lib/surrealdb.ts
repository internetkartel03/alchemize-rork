import Surreal from 'surrealdb.js';

interface ConnectionConfig {
  endpoint: string;
  namespace: string;
  database: string;
  token: string;
}

let db: Surreal | null = null;
let connecting: Promise<Surreal> | null = null;

function getConfig(): ConnectionConfig {
  const endpoint = process.env.EXPO_PUBLIC_RORK_DB_ENDPOINT;
  const namespace = process.env.EXPO_PUBLIC_RORK_DB_NAMESPACE;
  const token = process.env.EXPO_PUBLIC_RORK_DB_TOKEN;

  if (!endpoint || !namespace || !token) {
    throw new Error('Missing SurrealDB configuration');
  }

  return { endpoint, namespace, database: namespace, token };
}

async function createConnection(): Promise<Surreal> {
  const { endpoint, namespace, database, token } = getConfig();
  const client = new Surreal();

  try {
    await client.connect(endpoint, {
      namespace,
      database,
      auth: token,
    });
  } catch (error) {
    // Never cache a client that failed to connect: dispose it so the next
    // request starts from a clean slate.
    void client.close().catch(() => {});
    console.error('[SurrealDB] Connection error:', error);
    throw error;
  }

  db = client;
  console.log('[SurrealDB] Connected successfully');
  return client;
}

function isHealthy(client: Surreal | null): client is Surreal {
  if (!client) return false;
  return (client.status as string | undefined) === 'connected';
}

function discardStaleClient(): void {
  const stale = db;
  db = null;
  if (stale) {
    stale.close().catch(() => {});
  }
}

/**
 * Resolve a connected client, connecting on first use.
 *
 * Concurrent callers share the single in-flight connection attempt, and a
 * connection that dropped (or failed to open) is discarded and retried
 * instead of being handed out for every subsequent request.
 */
export function initSurrealDB(): Promise<Surreal> {
  if (isHealthy(db)) return Promise.resolve(db);
  if (connecting) return connecting;

  if (db) discardStaleClient();

  connecting = createConnection().finally(() => {
    connecting = null;
  });

  return connecting;
}

export async function getSurrealDB(): Promise<Surreal> {
  return initSurrealDB();
}

/** Close the shared connection, e.g. on shutdown. */
export async function closeSurrealDB(): Promise<void> {
  const current = db;
  db = null;
  connecting = null;
  if (current) {
    await current.close().catch(() => {});
  }
}

export interface User {
  [key: string]: unknown;
  id: string;
  email: string;
  name: string;
  passwordHash: string;
  createdAt: number;
}
