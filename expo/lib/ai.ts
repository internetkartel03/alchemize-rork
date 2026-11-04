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

const getAiBaseUrl = () => (process.env.EXPO_PUBLIC_AI_API_URL || '').replace(/\/+$/, '');

export function isAiConfigured(): boolean {
  return Boolean(getAiBaseUrl());
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
    throw new Error('AI service is not configured');
  }

  const response = await fetch(`${baseUrl}/api/ai/object`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ messages, schema: z.toJSONSchema(schema) }),
  });

  if (!response.ok) {
    let message = `AI request failed (${response.status})`;
    try {
      const body = await response.json();
      if (body?.error) message = body.error;
    } catch {
      // Keep the status-based message when the body is not JSON.
    }
    throw new Error(message);
  }

  const payload = await response.json();
  return schema.parse(payload.object);
}
