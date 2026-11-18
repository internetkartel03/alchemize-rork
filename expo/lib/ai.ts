import { z } from 'zod';

/**
 * Client for this app's own AI service (see backend/ai/server.mjs).
 *
 * The model provider key lives only in the backend service, so it never ships in
 * the Expo bundle. Set EXPO_PUBLIC_AI_API_URL to that service's URL.
 */

export type AiMessageContentPart =
  | { type: 'text'; text: string }
  | { type: 'image'; image: string };

export interface AiMessage {
  role: 'user' | 'assistant' | 'system';
  content: string | AiMessageContentPart[];
}

const REQUEST_TIMEOUT_MS = 30_000;
const RETRY_DELAY_MS = 800;

class AiRequestError extends Error {
  readonly retryable: boolean;

  constructor(message: string, retryable: boolean) {
    super(message);
    this.name = 'AiRequestError';
    this.retryable = retryable;
  }
}

const getAiBaseUrl = () => (process.env.EXPO_PUBLIC_AI_API_URL || '').replace(/\/+$/, '');

export function isAiConfigured(): boolean {
  return Boolean(getAiBaseUrl());
}

const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

async function postObject(baseUrl: string, body: string): Promise<unknown> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const response = await fetch(`${baseUrl}/api/ai/object`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
      signal: controller.signal,
    });

    if (!response.ok) {
      let message = `AI request failed (${response.status})`;
      try {
        const errorBody = await response.json();
        if (errorBody?.error) message = errorBody.error;
      } catch {
        // Keep the status-based message when the body is not JSON.
      }
      // Timeouts, rate limits and provider outages are worth one more attempt.
      throw new AiRequestError(message, response.status === 429 || response.status >= 500);
    }

    return await response.json();
  } catch (error) {
    if (error instanceof AiRequestError) throw error;
    if ((error as { name?: string })?.name === 'AbortError') {
      throw new AiRequestError('The AI request timed out. Please try again.', true);
    }
    throw new AiRequestError('Could not reach the AI service. Check your connection and try again.', true);
  } finally {
    clearTimeout(timeout);
  }
}

export async function generateObject<T extends z.ZodType>({
  messages,
  schema,
}: {
  messages: AiMessage[];
  schema: T;
}): Promise<z.infer<T>> {
  const baseUrl = getAiBaseUrl();
  if (!baseUrl) {
    throw new Error('AI service is not configured. Add EXPO_PUBLIC_AI_API_URL to the build.');
  }

  const body = JSON.stringify({ messages, schema: z.toJSONSchema(schema) });

  let lastError: unknown;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const payload = (await postObject(baseUrl, body)) as { object?: unknown };
      try {
        return schema.parse(payload?.object);
      } catch {
        // A malformed model answer is worth one fresh attempt.
        throw new AiRequestError('The AI returned an unexpected answer. Please try again.', true);
      }
    } catch (error) {
      lastError = error;
      const retryable = error instanceof AiRequestError && error.retryable;
      if (!retryable || attempt === 1) break;
      await wait(RETRY_DELAY_MS);
    }
  }

  throw lastError instanceof Error ? lastError : new Error('AI request failed');
}
