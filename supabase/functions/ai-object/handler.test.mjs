import test from 'node:test';
import assert from 'node:assert/strict';
import { createAiObjectHandler } from './handler.mjs';

const payload = {
  messages: [{ role: 'user', content: 'Estimate calories for this meal.' }],
  schema: {
    type: 'object',
    properties: { calories: { type: 'number' } },
    required: ['calories'],
    additionalProperties: false,
  },
};

function makeRequest(body = payload, headers = {}) {
  return new Request('https://example.test/functions/v1/ai-object', {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });
}

function makeContext(quota = { allowed: true, retry_after_seconds: 0 }, rpcError = null) {
  return {
    jwtClaims: { sub: 'test-user-id' },
    supabase: {
      rpc: async (name) => {
        assert.equal(name, 'consume_ai_request');
        return { data: [quota], error: rpcError };
      },
    },
  };
}

function silentLogger() {
  return { warn() {} };
}

test('rejects unauthenticated calls before quota or provider work', async () => {
  let rpcCalls = 0;
  let providerCalls = 0;
  const handler = createAiObjectHandler({
    env: () => 'test-only-key',
    fetchImpl: async () => { providerCalls += 1; throw new Error('must not call provider'); },
    logger: silentLogger(),
  });
  const context = makeContext();
  context.jwtClaims = {};
  context.supabase.rpc = async () => { rpcCalls += 1; return { data: [{ allowed: true }], error: null }; };

  const response = await handler(makeRequest(), context);
  assert.equal(response.status, 401);
  assert.equal(rpcCalls, 0);
  assert.equal(providerCalls, 0);
});

test('rejects oversized bodies without calling quota or provider', async () => {
  let rpcCalls = 0;
  let providerCalls = 0;
  const handler = createAiObjectHandler({
    env: () => 'test-only-key',
    fetchImpl: async () => { providerCalls += 1; throw new Error('must not call provider'); },
    logger: silentLogger(),
  });
  const context = makeContext();
  context.supabase.rpc = async () => { rpcCalls += 1; return { data: [{ allowed: true }], error: null }; };

  const response = await handler(makeRequest(payload, { 'content-length': String(16 * 1024 * 1024 + 1) }), context);
  assert.equal(response.status, 413);
  assert.equal(rpcCalls, 0);
  assert.equal(providerCalls, 0);
});

test('rejects malformed payloads without calling quota or provider', async () => {
  let rpcCalls = 0;
  let providerCalls = 0;
  const handler = createAiObjectHandler({
    env: () => 'test-only-key',
    fetchImpl: async () => { providerCalls += 1; throw new Error('must not call provider'); },
    logger: silentLogger(),
  });
  const context = makeContext();
  context.supabase.rpc = async () => { rpcCalls += 1; return { data: [{ allowed: true }], error: null }; };

  const response = await handler(makeRequest({ messages: [], schema: {} }), context);
  assert.equal(response.status, 400);
  assert.equal(rpcCalls, 0);
  assert.equal(providerCalls, 0);
});

test('fails closed when the provider secret is missing', async () => {
  let rpcCalls = 0;
  let providerCalls = 0;
  const handler = createAiObjectHandler({
    env: () => undefined,
    fetchImpl: async () => { providerCalls += 1; throw new Error('must not call provider'); },
    logger: silentLogger(),
  });
  const context = makeContext();
  context.supabase.rpc = async () => { rpcCalls += 1; return { data: [{ allowed: true }], error: null }; };

  const response = await handler(makeRequest(), context);
  assert.equal(response.status, 503);
  assert.equal(rpcCalls, 0);
  assert.equal(providerCalls, 0);
});

test('fails closed when the quota RPC is unavailable', async () => {
  let providerCalls = 0;
  const handler = createAiObjectHandler({
    env: () => 'test-only-key',
    fetchImpl: async () => { providerCalls += 1; throw new Error('must not call provider'); },
    logger: silentLogger(),
  });
  const response = await handler(makeRequest(), makeContext(null, { message: 'database unavailable' }));
  assert.equal(response.status, 503);
  assert.equal(providerCalls, 0);
});

test('returns 429 with retry guidance when the user quota is exhausted', async () => {
  let providerCalls = 0;
  const handler = createAiObjectHandler({
    env: () => 'test-only-key',
    fetchImpl: async () => { providerCalls += 1; throw new Error('must not call provider'); },
    logger: silentLogger(),
  });
  const response = await handler(makeRequest(), makeContext({ allowed: false, retry_after_seconds: 37 }));
  assert.equal(response.status, 429);
  assert.equal(response.headers.get('retry-after'), '37');
  assert.equal(providerCalls, 0);
});

test('uses a mocked provider and returns the generated object', async () => {
  let providerCalls = 0;
  let providerRequest;
  const handler = createAiObjectHandler({
    env: (name) => ({ AI_API_KEY: 'test-only-key', AI_MODEL: 'test-model' })[name],
    fetchImpl: async (url, init) => {
      providerCalls += 1;
      providerRequest = { url, init };
      return new Response(JSON.stringify({ choices: [{ message: { content: '{"calories": 321}' } }] }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      });
    },
    logger: silentLogger(),
  });

  const response = await handler(makeRequest(), makeContext());
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { object: { calories: 321 } });
  assert.equal(providerCalls, 1);
  assert.equal(providerRequest.url, 'https://api.openai.com/v1/chat/completions');
  assert.equal(providerRequest.init.headers.authorization, 'Bearer test-only-key');
  const sent = JSON.parse(providerRequest.init.body);
  assert.equal(sent.model, 'test-model');
  assert.match(sent.messages[0].content, /JSON Schema/);
  assert.equal(sent.messages[1].content, 'Estimate calories for this meal.');
});

test('converts validated base64 images to provider data URLs', async () => {
  let providerRequest;
  const imagePayload = {
    messages: [{ role: 'user', content: [
      { type: 'text', text: 'Analyze this meal.' },
      { type: 'image', image: 'aGVsbG8=' },
    ] }],
    schema: { type: 'object', properties: { food: { type: 'string' } } },
  };
  const handler = createAiObjectHandler({
    env: () => 'test-only-key',
    fetchImpl: async (_url, init) => {
      providerRequest = init;
      return new Response(JSON.stringify({ choices: [{ message: { content: '{"food":"salad"}' } }] }), { status: 200 });
    },
    logger: silentLogger(),
  });

  const response = await handler(makeRequest(imagePayload), makeContext());
  assert.equal(response.status, 200);
  const sent = JSON.parse(providerRequest.body);
  assert.deepEqual(sent.messages[1].content[1], {
    type: 'image_url',
    image_url: { url: 'data:image/jpeg;base64,aGVsbG8=' },
  });
});

test('does not expose provider error details to the app', async () => {
  const handler = createAiObjectHandler({
    env: () => 'test-only-key',
    fetchImpl: async () => new Response('private provider diagnostic', { status: 500 }),
    logger: silentLogger(),
  });
  const response = await handler(makeRequest(), makeContext());
  assert.equal(response.status, 502);
  assert.deepEqual(await response.json(), { error: 'AI service is temporarily unavailable.' });
});
