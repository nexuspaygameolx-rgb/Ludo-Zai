import { corsHeaders, jsonResponse, requireAuthUser } from "../_shared/http.ts";
import { serverRollDice } from "../_shared/matchService.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const user = await requireAuthUser(req);
    const { match_id } = await req.json();
    const result = await serverRollDice(String(match_id), user.id);
    return jsonResponse(result);
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
