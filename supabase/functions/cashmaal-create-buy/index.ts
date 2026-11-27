import { corsHeaders, getServiceClient, jsonResponse, requireAuthUser } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const user = await requireAuthUser(req);
    const { asset_type, asset_amount } = await req.json();
    const db = getServiceClient();

    const { data: cfg } = await db.from("app_remote_config").select("cashmaal_public_config").eq("id", 1).single();
    const cm = cfg?.cashmaal_public_config;
    if (!cm?.enabled) throw new Error("CashMaal Store is currently disabled by Admin");

    const amount = Math.max(1, Number(asset_amount));
    let pkr = 0;
    let rate = 0;
    if (asset_type === "coins") {
      rate = Number(cm.coins_buy_rate_pkr_per_1000);
      pkr = (amount / 1000) * rate;
    } else if (asset_type === "gems") {
      rate = Number(cm.gems_buy_rate_pkr_per_10);
      pkr = (amount / 10) * rate;
    } else {
      throw new Error("Invalid asset type for purchase");
    }

    const { data: order, error } = await db
      .from("cashmaal_orders")
      .insert({
        user_id: user.id,
        order_type: "buy",
        asset_type,
        asset_amount: amount,
        pkr_amount: Number(pkr.toFixed(2)),
        rate_applied: rate,
        status: "pending",
      })
      .select()
      .single();
    if (error) throw error;

    const merchantId = Deno.env.get("CASHMAAL_MERCHANT_ID");
    const gatewayBase = Deno.env.get("CASHMAAL_CHECKOUT_BASE_URL");
    if (!merchantId || !gatewayBase) {
      throw new Error("CashMaal gateway credentials not yet configured in Vault");
    }
    const checkoutUrl = `${gatewayBase}?merchant_id=${encodeURIComponent(merchantId)}&order_id=${order.id}&amount=${order.pkr_amount}&currency=PKR`;

    return jsonResponse({ order, checkout_url: checkoutUrl });
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
