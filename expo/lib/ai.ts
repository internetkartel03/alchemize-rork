import { z } from 'zod';
import { getSupabase } from '@/lib/supabase';

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

const hasSupabaseConfig = () => Boolean(
  process.env.EXPO_PUBLIC_SUPABASE_URL && process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY,
);

export function isAiConfigured(): boolean {
  return hasSupabaseConfig();
}

export async function generateObject<T extends z.ZodType>({
  messages,
  schema,
}: {
  messages: AiMessage[];
  schema: T;
}): Promise<z.infer<T>> {
  if (!hasSupabaseConfig()) {
    throw new Error('AI service is not configured');
  }

  const { data, error } = await getSupabase().functions.invoke<{ object: unknown }>('ai-object', {
    body: { messages, schema: z.toJSONSchema(schema) },
  });

  if (error) {
    let message = error.message || 'AI request failed';
    const context = (error as { context?: unknown }).context;
    if (context && typeof context === 'object' && 'json' in context && typeof context.json === 'function') {
      const response = context as {
        json: () => Promise<unknown>;
        clone?: () => { json: () => Promise<unknown> };
        status?: number;
      };
      try {
        const source = response.clone ? response.clone() : response;
        const body = await source.json();
        if (body && typeof body === 'object' && 'error' in body && typeof body.error === 'string') {
          message = body.error;
        } else if (typeof response.status === 'number') {
          message = `AI request failed (${response.status})`;
        }
      } catch {
        if (typeof response.status === 'number') message = `AI request failed (${response.status})`;
      }
    }
    throw new Error(message);
  }

  if (!data || typeof data !== 'object' || !('object' in data)) {
    throw new Error('AI service returned an invalid response');
  }
  return schema.parse(data.object);
}
