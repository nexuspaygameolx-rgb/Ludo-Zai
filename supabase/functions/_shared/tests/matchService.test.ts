import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { DEFAULT_KUTI_CONFIG } from "../ludo_rules/config.ts";
import { rollServerDice } from "../ludo_rules/dice.ts";
import { PlayerState } from "../ludo_rules/models.ts";

Deno.test("Server dice auto-switches to 1 die when 3 tokens are finished", () => {
  const player: PlayerState = {
    playerId: "u1",
    name: "Ali",
    color: "red",
    killsCount: 0,
    kutiCount: 0,
    consecutiveSixes: 0,
    tokens: [
      { id: "red_0", owner: "red", zone: "finished", mainTrackIndex: -1, progressSteps: 56, homeColumnColor: "red", homeColumnDepth: 6, isKuti: false },
      { id: "red_1", owner: "red", zone: "finished", mainTrackIndex: -1, progressSteps: 56, homeColumnColor: "red", homeColumnDepth: 6, isKuti: false },
      { id: "red_2", owner: "red", zone: "finished", mainTrackIndex: -1, progressSteps: 56, homeColumnColor: "red", homeColumnDepth: 6, isKuti: false },
      { id: "red_3", owner: "red", zone: "mainTrack", mainTrackIndex: 12, progressSteps: 12, homeColumnColor: null, homeColumnDepth: 0, isKuti: false },
    ],
  };
  const roll = rollServerDice(player, DEFAULT_KUTI_CONFIG);
  assertEquals(roll.values.length, 1);
});
