import { createServer } from 'node:http';

/**
 * AI service for Alchemize.
 *
 * A thin, dependency-free proxy in front of an OpenAI-compatible chat completions
 * API. The Expo app posts structured-output requests here, so the provider key
 * stays server-side instead of shipping in the web bundle.
 *
 * Environment:
 *   AI_API_KEY   provider key (required for real responses)
 *   AI_BASE_URL  OpenAI-compatible base URL (default https://api.openai.com/v1)
 *   AI_MODEL     model id (default gpt-4o-mini)
 *   AI_PORT      listen port (default 8000)
 */

const PORT = Number(process.env.AI_PORT || 8000);
const API_KEY = process.env.AI_API_KEY;
const BASE_URL = (process.env.AI_BASE_URL || 'https://api.openai.com/v1').replace(/\/+$/, '');
const MODEL = process.env.AI_MODEL || 'gpt-4o-mini';
const MAX_BODY_BYTES = 16 * 1024 * 1024;

function setCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'content-type, authorization');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
}

function sendJson(res, status, body) {
  setCors(res);
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        reject(new Error('Request body is too large'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

function toOpenAiContent(content) {
  if (typeof content === 'string') return content;
  return content.map((part) => {
    if (part.type === 'image') {
      const image = part.image || '';
      const url = image.startsWith('data:') ? image : `data:image/jpeg;base64,${image}`;
      return { type: 'image_url', image_url: { url } };
    }
    return { type: 'text', text: part.text || '' };
  });
}

function buildMessages(messages, schema) {
  const system = [
    'You are a precise assistant for the Alchemize wellness app.',
    'Respond with a single JSON object only — no prose, no markdown fences.',
    'The JSON must validate against this JSON Schema:',
    JSON.stringify(schema),
  ].join('\n');

  return [
    { role: 'system', content: system },
    ...messages.map((message) => ({
      role: message.role === 'system' ? 'user' : message.role || 'user',
      content: toOpenAiContent(message.content),
    })),
  ];
}

function parseJsonContent(raw) {
  const text = String(raw || '').trim();
  try {
    return JSON.parse(text);
  } catch {
    const start = text.indexOf('{');
    const end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return JSON.parse(text.slice(start, end + 1));
    }
    throw new Error('The AI response was not valid JSON');
  }
}

async function handleObject(req, res) {
  if (!API_KEY) {
    sendJson(res, 503, {
      error: 'AI is not configured on the server. Add the AI_API_KEY secret to enable AI features.',
    });
    return;
  }

  let payload;
  try {
    payload = JSON.parse(await readBody(req));
  } catch {
    sendJson(res, 400, { error: 'Invalid JSON body' });
    return;
  }

  if (!Array.isArray(payload?.messages) || !payload.messages.length || !payload.schema) {
    sendJson(res, 400, { error: 'Both messages and schema are required' });
    return;
  }

  let response;
  try {
    response = await fetch(`${BASE_URL}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${API_KEY}`,
      },
      body: JSON.stringify({
        model: MODEL,
        messages: buildMessages(payload.messages, payload.schema),
        response_format: { type: 'json_object' },
        temperature: 0.2,
      }),
    });
  } catch (error) {
    console.error('[AI] Provider request failed:', error);
    sendJson(res, 502, { error: 'Could not reach the AI provider' });
    return;
  }

  if (!response.ok) {
    const detail = await response.text().catch(() => '');
    console.error('[AI] Provider returned', response.status, detail.slice(0, 500));
    sendJson(res, 502, {
      error:
        response.status === 401 || response.status === 403
          ? 'The AI provider rejected the server API key.'
          : `The AI provider returned an error (${response.status}).`,
    });
    return;
  }

  try {
    const data = await response.json();
    const content = data?.choices?.[0]?.message?.content;
    sendJson(res, 200, { object: parseJsonContent(content) });
  } catch (error) {
    console.error('[AI] Could not read the AI response:', error);
    sendJson(res, 502, { error: 'The AI response could not be parsed' });
  }
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url || '/', `http://localhost:${PORT}`);

  if (req.method === 'OPTIONS') {
    setCors(res);
    res.writeHead(204).end();
    return;
  }

  if (req.method === 'GET' && url.pathname === '/health') {
    sendJson(res, 200, { status: 'ok', configured: Boolean(API_KEY), model: MODEL });
    return;
  }

  if (req.method === 'POST' && url.pathname === '/api/ai/object') {
    await handleObject(req, res);
    return;
  }

  sendJson(res, 404, { error: 'Not found' });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[AI] Listening on 0.0.0.0:${PORT} (model: ${MODEL}, key: ${API_KEY ? 'set' : 'missing'})`);
});
