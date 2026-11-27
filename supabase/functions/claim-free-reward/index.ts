import { corsHeaders, getServiceClient, jsonResponse, requireAuthUser } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const user = await requireAuthUser(req);
    const { claim_type } = await req.json();
    const db = getServiceClient();

    await db.from("daily_free_claims").upsert({ user_id: user.id }, { onConflict: "user_id" });
    const { data: tracker } = await db.from("daily_free_claims").select("*").eq("user_id", user.id).single();

    let coinsAward = 0;
    let gemsAward = 0;

    if (claim_type === "four_hour_gift") {
      if (tracker?.last_four_hour_claim) {
        const diffHours = (Date.now() - new Date(tracker.last_four_hour_claim).getTime()) / 3600000;
        if (diffHours < 4) throw new Error("4-hour free gift is still cooling down");
      }
      coinsAward = 400;
      await db.from("daily_free_claims").update({ last_four_hour_claim: new Date().toISOString() }).eq("user_id", user.id);
    } else if (claim_type === "daily_streak") {
      const today = new Date().toISOString().slice(0, 10);
      if (tracker?.last_streak_claim_date === today) throw new Error("Today's login streak reward already claimed");
      const nextDay = ((tracker?.login_streak_day ?? 0) % 7) + 1;
      coinsAward = nextDay * 300;
      gemsAward = nextDay === 7 ? 20 : 2;
      await db
        .from("daily_free_claims")
        .update({ login_streak_day: nextDay, last_streak_claim_date: today })
        .eq("user_id", user.id);
    } else if (claim_type === "lucky_spin") {
      const prizes = [250, 500, 1000, 2000, 5000];
      const idx = crypto.getRandomValues(new Uint8Array(1))[0] % prizes.length;
      coinsAward = prizes[idx];
    } else {
      throw new Error("Invalid claim type");
    }

    await db.rpc("apply_wallet_delta", {
      p_user_id: user.id,
      p_coins_delta: coinsAward,
      p_gems_delta: gemsAward,
      p_reason: `free_${claim_type}`,
    });

    return jsonResponse({ ok: true, coins_awarded: coinsAward, gems_awarded: gemsAward });
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
