import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { DEFAULT_KUTI_CONFIG } from "../ludo_rules/config.ts";
import { executeServerMove, getLegalMovesServer } from "../ludo_rules/engine.ts";
import { PlayerState } from "../ludo_rules/models.ts";

Deno.test("Server 6+X Ghar Wali Ulti Kuti executes cleanly", () => {
  const p1: PlayerState = {
    playerId: "u1",
    name: "Ali",
    color: "red",
    killsCount: 0,
    kutiCount: 0,
    consecutiveSixes: 0,
    tokens: [
      { id: "red_0", owner: "red", zone: "finished", mainTrackIndex: -1, progressSteps: 56, homeColumnColor: "red", homeColumnDepth: 6, isKuti: false },
      { id: "red_1", owner: "red", zone: "mainTrack", mainTrackIndex: 4, progressSteps: 4, homeColumnColor: null, homeColumnDepth: 0, isKuti: false },
      { id: "red_2", owner: "red", zone: "yard", mainTrackIndex: -1, progressSteps: -1, homeColumnColor: null, homeColumnDepth: 0, isKuti: false },
      { id: "red_3", owner: "red", zone: "yard", mainTrackIndex: -1, progressSteps: -1, homeColumnColor: null, homeColumnDepth: 0, isKuti: false },
    ],
  };
  const p2: PlayerState = {
    playerId: "u2",
    name: "Usman",
    color: "green",
    killsCount: 0,
    kutiCount: 0,
    consecutiveSixes: 0,
    tokens: [
      { id: "green_0", owner: "green", zone: "homeColumn", mainTrackIndex: -1, progressSteps: 53, homeColumnColor: "green", homeColumnDepth: 3, isKuti: false },
      { id: "green_1", owner: "green", zone: "yard", mainTrackIndex: -1, progressSteps: -1, homeColumnColor: null, homeColumnDepth: 0, isKuti: false },
      { id: "green_2", owner: "green", zone: "yard", mainTrackIndex: -1, progressSteps: -1, homeColumnColor: null, homeColumnDepth: 0, isKuti: false },
      { id: "green_3", owner: "green", zone: "yard", mainTrackIndex: -1, progressSteps: -1, homeColumnColor: null, homeColumnDepth: 0, isKuti: false },
    ],
  };

  const moves = getLegalMovesServer(p1, [p1, p2], { values: [6, 3], used: [false, false] }, DEFAULT_KUTI_CONFIG);
  const kuti = moves.find((m) => m.moveType === "gharWaliUltiKuti" && m.tokenId === "red_1")!;
  const res = executeServerMove(p1, [p1, p2], kuti, DEFAULT_KUTI_CONFIG);
  assertEquals(res.triggeredUltiKuti, true);
  assertEquals(res.updatedPlayers[0].tokens[1].isKuti, true);
  assertEquals(res.updatedPlayers[1].tokens[0].zone, "yard");
});
