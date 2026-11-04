const MAX_BODY_BYTES = 16 * 1024 * 1024;
const MAX_IMAGE_CHARS = 15 * 1024 * 1024;
const MAX_SCHEMA_CHARS = 128 * 1024;
const MAX_MESSAGES = 12;
const MAX_CONTENT_PARTS = 8;
const MAX_TEXT_CHARS = 32_000;

class BodyTooLargeError extends Error {}

function jsonResponse(body, status, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
      ...extraHeaders,
    },
  });
}

function isRecord(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

async function readLimitedText(request) {
  const contentLength = Number(request.headers.get('content-length'));
  if (Number.isFinite(contentLength) && contentLength > MAX_BODY_BYTES) {
    throw new BodyTooLargeError();
  }

  const reader = request.body?.getReader();
  if (!reader) return '';

  const chunks = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > MAX_BODY_BYTES) {
        await reader.cancel();
        throw new BodyTooLargeError();
      }
      chunks.push(value);
    }
  } catch (error) {
    if (error instanceof BodyTooLargeError) throw error;
    throw new Error('Unable to read request body');
  }

  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(bytes);
}

function imagePayload(image) {
  if (typeof image !== 'string' || image.length === 0 || image.length > MAX_IMAGE_CHARS) return null;
  const prefix = /^data:image\/(?:jpeg|png|webp);base64,/i.exec(image)?.[0];
  const base64 = prefix ? image.slice(prefix.length) : image;
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(base64)) return null;
  return { base64, dataUrl: prefix ? image : `data:image/jpeg;base64,${image}` };
}

function validatePayload(payload) {
  if (!isRecord(payload)) return 'Request must be a JSON object.';
  if (!Array.isArray(payload.messages) || payload.messages.length === 0 || payload.messages.length > MAX_MESSAGES) {
    return 'Messages must be a non-empty array with at most 12 items.';
  }
  if (!isRecord(payload.schema)) return 'A JSON schema is required.';

  let schemaText;
  try {
    schemaText = JSON.stringify(payload.schema);
  } catch {
    return 'The JSON schema is invalid.';
  }
  if (schemaText.length > MAX_SCHEMA_CHARS) return 'The JSON schema is too large.';

  for (const message of payload.messages) {
    if (!isRecord(message) || !['system', 'user', 'assistant'].includes(message.role)) {
      return 'Each message must have a valid role.';
    }
    if (typeof message.content === 'string') {
      if (message.content.length > MAX_TEXT_CHARS) return 'Message text is too large.';
      continue;
    }
    if (!Array.isArray(message.content) || message.content.length === 0 || message.content.length > MAX_CONTENT_PARTS) {
      return 'Message content must be text or a supported content array.';
    }
    for (const part of message.content) {
      if (!isRecord(part)) return 'Message content contains an invalid item.';
      if (part.type === 'text' && typeof part.text === 'string' && part.text.length <= MAX_TEXT_CHARS) continue;
      if (part.type === 'image' && imagePayload(part.image)) continue;
      return 'Message content contains an unsupported or oversized item.';
    }
  }
  return null;
}

function providerMessages(messages, schema) {
  const systemMessage = {
    role: 'system',
    content: `You are a precise assistant for the Alchemize wellness app. Return one JSON object only, without markdown fences or surrounding prose. The output must follow this JSON Schema: ${JSON.stringify(schema)}`,
  };
  return [systemMessage, ...messages.map((message) => ({
    role: message.role === 'system' ? 'user' : message.role,
    content: typeof message.content === 'string'
      ? message.content
      : message.content.map((part) => {
          if (part.type === 'text') return { type: 'text', text: part.text };
          const image = imagePayload(part.image);
          return { type: 'image_url', image_url: { url: image.dataUrl } };
        }),
  }))];
}

function parseObjectContent(content) {
  if (typeof content !== 'string') throw new Error('Invalid provider content');
  const text = content.trim();
  try {
    const parsed = JSON.parse(text);
    if (isRecord(parsed)) return parsed;
  } catch {
    // Some models wrap an otherwise valid object in short explanatory text.
  }
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start >= 0 && end > start) {
    const parsed = JSON.parse(text.slice(start, end + 1));
    if (isRecord(parsed)) return parsed;
  }
  throw new Error('Provider did not return a JSON object');
}

export function createAiObjectHandler({
  env = (name) => globalThis.Deno?.env?.get(name),
  fetchImpl = globalThis.fetch,
  logger = console,
} = {}) {
  return async function handleAiObject(request, context = {}) {
    if (request.method !== 'POST') return jsonResponse({ error: 'Method not allowed.' }, 405, { allow: 'POST' });
    if (typeof context?.jwtClaims?.sub !== 'string' || context.jwtClaims.sub.length === 0) {
      return jsonResponse({ error: 'Authentication required.' }, 401);
    }
    if (!context.supabase || typeof context.supabase.rpc !== 'function') {
      return jsonResponse({ error: 'AI request limits are temporarily unavailable.' }, 503);
    }

    const apiKey = env('AI_API_KEY')?.trim();
    if (!apiKey) return jsonResponse({ error: 'AI service is not configured.' }, 503);

    let payload;
    try {
      payload = JSON.parse(await readLimitedText(request));
    } catch (error) {
      if (error instanceof BodyTooLargeError) return jsonResponse({ error: 'Request body is too large.' }, 413);
      return jsonResponse({ error: 'Request body must contain valid JSON.' }, 400);
    }
    const validationError = validatePayload(payload);
    if (validationError) return jsonResponse({ error: validationError }, 400);

    let quotaResult;
    try {
      quotaResult = await context.supabase.rpc('consume_ai_request');
    } catch {
      return jsonResponse({ error: 'AI request limits are temporarily unavailable.' }, 503);
    }
    if (quotaResult?.error) return jsonResponse({ error: 'AI request limits are temporarily unavailable.' }, 503);
    const quota = Array.isArray(quotaResult?.data) ? quotaResult.data[0] : quotaResult?.data;
    if (!quota || typeof quota.allowed !== 'boolean') {
      return jsonResponse({ error: 'AI request limits are temporarily unavailable.' }, 503);
    }
    if (!quota.allowed) {
      const retryAfter = Math.max(1, Math.min(86_400, Math.ceil(Number(quota.retry_after_seconds) || 60)));
      return jsonResponse({ error: 'AI request limit reached. Please try again later.' }, 429, { 'retry-after': String(retryAfter) });
    }

    const baseUrl = (env('AI_BASE_URL') || 'https://api.openai.com/v1').replace(/\/+$/, '');
    const model = env('AI_MODEL') || 'gpt-4o-mini';
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 45_000);
    let providerResponse;
    try {
      providerResponse = await fetchImpl(`${baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${apiKey}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          model,
          messages: providerMessages(payload.messages, payload.schema),
          temperature: 0,
          response_format: { type: 'json_object' },
        }),
        signal: controller.signal,
      });
    } catch (error) {
      clearTimeout(timeout);
      const status = error?.name === 'AbortError' ? 504 : 502;
      logger.warn?.('[ai-object] provider request failed', { status });
      return jsonResponse({ error: status === 504 ? 'AI service timed out.' : 'AI service is temporarily unavailable.' }, status);
    }
    clearTimeout(timeout);

    if (!providerResponse.ok) {
      logger.warn?.('[ai-object] provider returned an error', { status: providerResponse.status });
      return jsonResponse({ error: 'AI service is temporarily unavailable.' }, 502);
    }

    let providerData;
    try {
      providerData = await providerResponse.json();
    } catch {
      return jsonResponse({ error: 'AI service returned an invalid response.' }, 502);
    }
    try {
      const object = parseObjectContent(providerData?.choices?.[0]?.message?.content);
      return jsonResponse({ object }, 200);
    } catch {
      return jsonResponse({ error: 'AI service returned an invalid response.' }, 502);
    }
  };
}
