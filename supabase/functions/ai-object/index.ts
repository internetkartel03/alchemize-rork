import { withSupabase } from 'npm:@supabase/server@^1';
import { createAiObjectHandler } from './handler.mjs';

const handler = createAiObjectHandler({
  env: (name) => Deno.env.get(name),
});

export default {
  fetch: withSupabase({ auth: 'user' }, handler),
};
