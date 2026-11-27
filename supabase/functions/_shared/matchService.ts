import { getServiceClient } from "./http.ts";
import { LudoRulesConfig } from "./ludo_rules/config.ts";
import { rollServerDice } from "./ludo_rules/dice.ts";
import { executeServerMove, getLegalMovesServer } from "./ludo_rules/engine.ts";
import { LegalMove, PlayerState, TwinDiceRoll } from "./ludo_rules/models.ts";

export async function serverRollDice(matchId: string, userId: string) {
  const db = getServiceClient();
  const { data: match, error } = await db.from("live_matches").select("*").eq("id", matchId).single();
  if (error || !match) throw new Error("Match not found");
  if (match.status !== "active") throw new Error("Match is not active");

  const players = match.players_state as PlayerState[];
  const activePlayer = players[match.active_seat_index];
  if (!activePlayer || activePlayer.playerId !== userId) {
    throw new Error("Not your turn");
  }
  if (match.active_dice && !(match.active_dice as TwinDiceRoll).used.every(Boolean)) {
    throw new Error("Dice already rolled for this turn");
  }

  const config = match.rules_config as LudoRulesConfig;
  const dice = rollServerDice(activePlayer, config);
  const legalMoves = getLegalMovesServer(activePlayer, players, dice, config);

  // Auto-pass if no legal moves
  let nextSeat = match.active_seat_index;
  let storedDice: TwinDiceRoll | null = dice;
  if (legalMoves.length === 0) {
    nextSeat = (match.active_seat_index + 1) % players.length;
    storedDice = null;
  }

  const { error: updErr } = await db
    .from("live_matches")
    .update({
      active_dice: storedDice,
      active_seat_index: nextSeat,
      turn_deadline: new Date(Date.now() + 15000).toISOString(),
    })
    .eq("id", matchId);
  if (updErr) throw updErr;

  return { dice, legalMoves, autoPassed: legalMoves.length === 0, nextSeat };
}

export async function serverMakeMove(matchId: string, userId: string, moveIndex: number) {
  const db = getServiceClient();
  const { data: match, error } = await db.from("live_matches").select("*").eq("id", matchId).single();
  if (error || !match || match.status !== "active") throw new Error("Invalid match");

  const players = match.players_state as PlayerState[];
  const activePlayer = players[match.active_seat_index];
  if (!activePlayer || activePlayer.playerId !== userId) {
    await db.from("anticheat_strikes").insert({ user_id: userId, match_id: matchId, reason: "Out-of-turn move attempt" });
    throw new Error("Out of turn");
  }

  const config = match.rules_config as LudoRulesConfig;
  const dice = match.active_dice as TwinDiceRoll;
  if (!dice) throw new Error("Roll dice first");

  const legalMoves = getLegalMovesServer(activePlayer, players, dice, config);
  const chosenMove: LegalMove | undefined = legalMoves[moveIndex];
  if (!chosenMove) {
    await db.from("anticheat_strikes").insert({ user_id: userId, match_id: matchId, reason: "Illegal move index submitted" });
    throw new Error("Illegal move");
  }

  const outcome = executeServerMove(activePlayer, players, chosenMove, config);
  const nextUsed = [...dice.used];
  for (const idx of chosenMove.diceUsedIndices) nextUsed[idx] = true;
  const updatedDice: TwinDiceRoll = { values: dice.values, used: nextUsed };
  const allDiceUsed = nextUsed.every(Boolean);

  let nextSeat = match.active_seat_index;
  let finalDice: TwinDiceRoll | null = updatedDice;

  if (allDiceUsed) {
    finalDice = null;
    if (!outcome.grantBonusTurn && !dice.values.includes(6)) {
      nextSeat = (match.active_seat_index + 1) % players.length;
    }
  }

  await db
    .from("live_matches")
    .update({
      players_state: outcome.updatedPlayers,
      active_dice: finalDice,
      active_seat_index: nextSeat,
      winner_color: outcome.winnerColor,
      status: outcome.winnerColor ? "finished" : "active",
      turn_deadline: new Date(Date.now() + 15000).toISOString(),
    })
    .eq("id", matchId);

  return {
    outcome,
    nextSeat,
    remainingDice: finalDice,
  };
}
