import { corsHeaders, getServiceClient, jsonResponse } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const payload = await req.json();
    const secretPin = Deno.env.get("CASHMAAL_SECRET_PIN") ?? "";
    if (!secretPin || payload.secret_pin !== secretPin) {
      return jsonResponse({ error: "Invalid IPN signature" }, 403);
    }

    const orderId = String(payload.order_id);
    const txnId = String(payload.txn_id);
    const db = getServiceClient();

    const { data: order } = await db.from("cashmaal_orders").select("*").eq("id", orderId).single();
    if (!order || order.order_type !== "buy") return jsonResponse({ error: "Order not found" }, 404);
    if (order.status === "completed") return jsonResponse({ ok: true, already_processed: true });

    const coinsDelta = order.asset_type === "coins" ? order.asset_amount : 0;
    const gemsDelta = order.asset_type === "gems" ? order.asset_amount : 0;

    await db.rpc("apply_wallet_delta", {
      p_user_id: order.user_id,
      p_coins_delta: coinsDelta,
      p_gems_delta: gemsDelta,
      p_reason: "cashmaal_buy_deposit",
      p_reference_id: txnId,
      p_note: `CashMaal Buy Order ${order.id} (${order.pkr_amount} PKR)`,
    });

    await db
      .from("cashmaal_orders")
      .update({ status: "completed", gateway_txn_id: txnId, updated_at: new Date().toISOString() })
      .eq("id", order.id);

    return jsonResponse({ ok: true });
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
