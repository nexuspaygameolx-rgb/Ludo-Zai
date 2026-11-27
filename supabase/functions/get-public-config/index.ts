import { corsHeaders, getServiceClient, jsonResponse } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const db = getServiceClient();
    const { data, error } = await db.from("app_remote_config").select("*").eq("id", 1).single();
    if (error) throw error;
    return jsonResponse({ config: data });
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
