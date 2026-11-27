import { corsHeaders, getServiceClient, jsonResponse, requireAuthUser } from "../_shared/http.ts";
import { DEFAULT_KUTI_CONFIG } from "../_shared/ludo_rules/config.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const user = await requireAuthUser(req);
    const body = await req.json();
    const mode = body.mode ?? "online_1v1";
    const entryCoins = Math.max(0, Number(body.entry_coins ?? 500));
    const rulesConfig = { ...DEFAULT_KUTI_CONFIG, ...(body.rules_config ?? {}) };
    const includeGeminiAi = Boolean(body.include_gemini_ai);

    const db = getServiceClient();
    if (entryCoins > 0) {
      const { error: debitErr } = await db.rpc("apply_wallet_delta", {
        p_user_id: user.id,
        p_coins_delta: -entryCoins,
        p_gems_delta: 0,
        p_reason: "match_entry_escrow",
        p_note: `Room creation entry fee (${mode})`,
      });
      if (debitErr) throw new Error(debitErr.message);
    }

    const { data: profile } = await db.from("profiles").select("display_name").eq("id", user.id).single();
    const roomCode = Math.random().toString(36).substring(2, 8).toUpperCase();

    const playersState = [
      {
        playerId: user.id,
        name: profile?.display_name ?? "Host",
        color: "red",
        isBot: false,
        isGeminiAi: false,
        killsCount: 0,
        kutiCount: 0,
        consecutiveSixes: 0,
        tokens: [0, 1, 2, 3].map((i) => ({
          id: `red_${i}`,
          owner: "red",
          zone: "yard",
          mainTrackIndex: -1,
          progressSteps: -1,
          homeColumnColor: null,
          homeColumnDepth: 0,
          isKuti: false,
        })),
      },
    ];

    if (includeGeminiAi) {
      const aiColor = rulesConfig.teamMode2v2 ? "yellow" : "green";
      playersState.push({
        playerId: `gemini_${crypto.randomUUID()}`,
        name: body.gemini_persona_name ?? "Maya (Gemini AI)",
        color: aiColor,
        isBot: true,
        isGeminiAi: true,
        killsCount: 0,
        kutiCount: 0,
        consecutiveSixes: 0,
        tokens: [0, 1, 2, 3].map((i) => ({
          id: `${aiColor}_${i}`,
          owner: aiColor,
          zone: "yard",
          mainTrackIndex: -1,
          progressSteps: -1,
          homeColumnColor: null,
          homeColumnDepth: 0,
          isKuti: false,
        })),
      });
    }

    const { data: match, error } = await db
      .from("live_matches")
      .insert({
        room_code: roomCode,
        mode,
        entry_coins: entryCoins,
        prize_pool_coins: entryCoins * (includeGeminiAi ? 2 : 1),
        rules_config: rulesConfig,
        status: includeGeminiAi && mode === "online_1v1" ? "active" : "waiting",
        players_state: playersState,
        created_by: user.id,
      })
      .select()
      .single();

    if (error) throw error;
    return jsonResponse({ match });
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
