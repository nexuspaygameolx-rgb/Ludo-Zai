import { corsHeaders, getServiceClient, jsonResponse, requireAuthUser } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const user = await requireAuthUser(req);
    const { action, reward_type, session_id } = await req.json();
    const db = getServiceClient();

    const { data: cfg } = await db.from("app_remote_config").select("adsterra_config").eq("id", 1).single();
    const adCfg = cfg?.adsterra_config;
    if (!adCfg?.enabled) throw new Error("Adsterra rewards are currently paused");

    if (action === "start") {
      const { data: session, error } = await db
        .from("adsterra_sessions")
        .insert({ user_id: user.id, reward_type: reward_type ?? "coins" })
        .select()
        .single();
      if (error) throw error;
      return jsonResponse({ session_id: session.id, ad_url: adCfg.rewarded_ad_url || adCfg.direct_link_url });
    }

    if (action === "claim") {
      const { data: session } = await db
        .from("adsterra_sessions")
        .select("*")
        .eq("id", session_id)
        .eq("user_id", user.id)
        .single();
      if (!session || session.status !== "issued") throw new Error("Invalid or already claimed ad session");

      const elapsedSec = (Date.now() - new Date(session.issued_at).getTime()) / 1000;
      if (elapsedSec < 10) throw new Error("Ad watch duration not verified yet");

      const coinsReward = session.reward_type === "coins" ? Number(adCfg.reward_coins ?? 500) : 0;
      const gemsReward = session.reward_type === "gems" ? Number(adCfg.reward_gems ?? 5) : 0;

      if (coinsReward > 0 || gemsReward > 0) {
        await db.rpc("apply_wallet_delta", {
          p_user_id: user.id,
          p_coins_delta: coinsReward,
          p_gems_delta: gemsReward,
          p_reason: "adsterra_reward",
          p_reference_id: session.id,
        });
      }

      await db
        .from("adsterra_sessions")
        .update({ status: "claimed", claimed_at: new Date().toISOString() })
        .eq("id", session.id);

      return jsonResponse({ ok: true, coins_awarded: coinsReward, gems_awarded: gemsReward });
    }

    throw new Error("Invalid action");
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
