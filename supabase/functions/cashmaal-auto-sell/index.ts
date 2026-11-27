import { corsHeaders, getServiceClient, jsonResponse, requireAuthUser } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const user = await requireAuthUser(req);
    const { asset_type, asset_amount, cashmaal_account } = await req.json();
    if (!cashmaal_account) throw new Error("CashMaal receiver account/email is required");

    const db = getServiceClient();
    const { data: cfg } = await db.from("app_remote_config").select("cashmaal_public_config").eq("id", 1).single();
    const cm = cfg?.cashmaal_public_config;
    if (!cm?.enabled) throw new Error("CashMaal Store is currently disabled");

    const amount = Number(asset_amount);
    let pkr = 0;
    let rate = 0;

    if (asset_type === "coins") {
      if (amount < Number(cm.min_sell_coins)) throw new Error(`Minimum sell amount is ${cm.min_sell_coins} coins`);
      rate = Number(cm.coins_sell_rate_pkr_per_1000);
      pkr = (amount / 1000) * rate;
      await db.rpc("apply_wallet_delta", {
        p_user_id: user.id,
        p_coins_delta: -amount,
        p_gems_delta: 0,
        p_reason: "cashmaal_sell_escrow",
        p_note: `Sell ${amount} coins to Admin Store`,
      });
    } else if (asset_type === "gems") {
      if (amount < Number(cm.min_sell_gems)) throw new Error(`Minimum sell amount is ${cm.min_sell_gems} gems`);
      rate = Number(cm.gems_sell_rate_pkr_per_10);
      pkr = (amount / 10) * rate;
      await db.rpc("apply_wallet_delta", {
        p_user_id: user.id,
        p_coins_delta: 0,
        p_gems_delta: -amount,
        p_reason: "cashmaal_sell_escrow",
        p_note: `Sell ${amount} gems to Admin Store`,
      });
    } else if (asset_type === "trophies") {
      if (amount < Number(cm.min_sell_trophies)) throw new Error(`Minimum sell amount is ${cm.min_sell_trophies} trophies`);
      rate = Number(cm.trophies_sell_rate_pkr_per_100);
      pkr = (amount / 100) * rate;
      const { data: prof } = await db.from("profiles").select("trophies").eq("id", user.id).single();
      if (!prof || prof.trophies < amount) throw new Error("Insufficient trophies");
      await db.from("profiles").update({ trophies: prof.trophies - amount }).eq("id", user.id);
    } else {
      throw new Error("Unsupported asset type");
    }

    const { data: order, error } = await db
      .from("cashmaal_orders")
      .insert({
        user_id: user.id,
        order_type: "sell",
        asset_type,
        asset_amount: amount,
        pkr_amount: Number(pkr.toFixed(2)),
        rate_applied: rate,
        cashmaal_account: String(cashmaal_account).trim(),
        status: cm.auto_payout_enabled ? "processing" : "pending",
      })
      .select()
      .single();
    if (error) throw error;

    return jsonResponse({ order, message: "Sell request locked in escrow and queued for CashMaal payout." });
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
