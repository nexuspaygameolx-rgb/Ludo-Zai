import { corsHeaders, getServiceClient, jsonResponse, requireAuthUser } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const user = await requireAuthUser(req);
    const { dice_id } = await req.json();
    const db = getServiceClient();

    const { data: inv } = await db
      .from("user_inventory")
      .select("*")
      .eq("user_id", user.id)
      .eq("item_type", "dice")
      .eq("item_id", dice_id)
      .single();
    if (!inv) throw new Error("Dice not unlocked yet");
    if (inv.level >= 5) throw new Error("Dice is already at Max Level 5");

    const { data: cat } = await db.from("dice_catalog").select("*").eq("id", dice_id).single();
    if (!cat) throw new Error("Dice catalog entry missing");

    const requiredShards = cat.shards_per_level[inv.level - 1];
    const requiredGems = cat.gem_cost_per_level[inv.level - 1];
    if (inv.shards < requiredShards) throw new Error(`Need ${requiredShards} shards (have ${inv.shards})`);

    await db.rpc("apply_wallet_delta", {
      p_user_id: user.id,
      p_coins_delta: 0,
      p_gems_delta: -requiredGems,
      p_reason: "dice_upgrade",
      p_reference_id: dice_id,
      p_note: `Upgraded ${dice_id} to Level ${inv.level + 1}`,
    });

    const { data: updated, error } = await db
      .from("user_inventory")
      .update({
        level: inv.level + 1,
        shards: inv.shards - requiredShards,
      })
      .eq("user_id", user.id)
      .eq("item_type", "dice")
      .eq("item_id", dice_id)
      .select()
      .single();
    if (error) throw error;

    return jsonResponse({ ok: true, inventory: updated });
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
