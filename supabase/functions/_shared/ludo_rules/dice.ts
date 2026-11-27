import { LudoRulesConfig } from "./config.ts";
import { PlayerState, TwinDiceRoll } from "./models.ts";

export function rollServerDice(player: PlayerState, config: LudoRulesConfig): TwinDiceRoll {
  const finished = player.tokens.filter((t) => t.zone === "finished").length;
  const remaining = 4 - finished;
  const count = !config.kutiMode
    ? 1
    : config.autoSingleDiceOnLastToken && remaining <= 1
    ? 1
    : 2;

  const bytes = new Uint8Array(count);
  crypto.getRandomValues(bytes);
  const values = Array.from(bytes, (b) => (b % 6) + 1);
  return {
    values,
    used: Array(count).fill(false),
  };
}
