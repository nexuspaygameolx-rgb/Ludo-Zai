import { corsHeaders, getServiceClient, jsonResponse, requireAuthUser } from "../_shared/http.ts";

const COLORS = ["red", "green", "yellow", "blue"] as const;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const user = await requireAuthUser(req);
    const { room_code } = await req.json();
    const db = getServiceClient();

    const { data: match, error } = await db
      .from("live_matches")
      .select("*")
      .eq("room_code", String(room_code).toUpperCase())
      .single();
    if (error || !match) throw new Error("Room not found");
    if (match.status !== "waiting") throw new Error("Room already started or finished");

    const players = match.players_state as Array<Record<string, unknown>>;
    if (players.some((p) => p.playerId === user.id)) {
      return jsonResponse({ match });
    }
    const maxPlayers = match.mode === "online_1v1" ? 2 : 4;
    if (players.length >= maxPlayers) throw new Error("Room is full");

    if (match.entry_coins > 0) {
      const { error: debitErr } = await db.rpc("apply_wallet_delta", {
        p_user_id: user.id,
        p_coins_delta: -match.entry_coins,
        p_gems_delta: 0,
        p_reason: "match_entry_escrow",
        p_reference_id: match.id,
      });
      if (debitErr) throw new Error(debitErr.message);
    }

    const { data: profile } = await db.from("profiles").select("display_name").eq("id", user.id).single();
    const seatColor = COLORS[players.length];
    players.push({
      playerId: user.id,
      name: profile?.display_name ?? `Player ${players.length + 1}`,
      color: seatColor,
      isBot: false,
      isGeminiAi: false,
      killsCount: 0,
      kutiCount: 0,
      consecutiveSixes: 0,
      tokens: [0, 1, 2, 3].map((i) => ({
        id: `${seatColor}_${i}`,
        owner: seatColor,
        zone: "yard",
        mainTrackIndex: -1,
        progressSteps: -1,
        homeColumnColor: null,
        homeColumnDepth: 0,
        isKuti: false,
      })),
    });

    const nextStatus = players.length >= maxPlayers ? "active" : "waiting";
    const { data: updated, error: updErr } = await db
      .from("live_matches")
      .update({
        players_state: players,
        prize_pool_coins: match.prize_pool_coins + match.entry_coins,
        status: nextStatus,
        turn_deadline: nextStatus === "active" ? new Date(Date.now() + 15000).toISOString() : null,
      })
      .eq("id", match.id)
      .select()
      .single();

    if (updErr) throw updErr;
    return jsonResponse({ match: updated });
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
