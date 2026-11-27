import { corsHeaders, jsonResponse, requireAuthUser } from "../_shared/http.ts";
import { serverMakeMove } from "../_shared/matchService.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const user = await requireAuthUser(req);
    const { match_id, move_index } = await req.json();
    const result = await serverMakeMove(String(match_id), user.id, Number(move_index));
    return jsonResponse(result);
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
