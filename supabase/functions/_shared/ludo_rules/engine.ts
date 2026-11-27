import { LudoRulesConfig } from "./config.ts";
import { LegalMove, PlayerColor, PlayerState, TwinDiceRoll } from "./models.ts";

const START_TILE: Record<PlayerColor, number> = { red: 0, green: 13, yellow: 26, blue: 39 };
const HOME_GATE: Record<PlayerColor, number> = { red: 50, green: 11, yellow: 24, blue: 37 };
const EIGHT_SAFE = new Set([0, 8, 13, 21, 26, 34, 39, 47]);
const FOUR_SAFE = new Set([0, 13, 26, 39]);

export function isSafeTile(idx: number, config: LudoRulesConfig): boolean {
  return config.safeZoneCount <= 4 ? FOUR_SAFE.has(idx) : EIGHT_SAFE.has(idx);
}

export function areTeammates(a: PlayerColor, b: PlayerColor, config: LudoRulesConfig): boolean {
  if (a === b) return true;
  if (!config.teamMode2v2) return false;
  return (
    (a === "red" && b === "yellow") ||
    (a === "yellow" && b === "red") ||
    (a === "green" && b === "blue") ||
    (a === "blue" && b === "green")
  );
}

export function getLegalMovesServer(
  activePlayer: PlayerState,
  allPlayers: PlayerState[],
  dice: TwinDiceRoll,
  config: LudoRulesConfig
): LegalMove[] {
  const moves: LegalMove[] = [];
  const unused = dice.values.map((_, i) => i).filter((i) => !dice.used[i]);
  if (unused.length === 0) return moves;

  const finishedCount = activePlayer.tokens.filter((t) => t.zone === "finished").length;

  // 1. Ghar Wali Ulti Kuti (6 + X)
  if (config.kutiMode && unused.length === 2 && finishedCount >= 1 && dice.values.includes(6)) {
    const sixIdx = dice.values[0] === 6 ? 0 : 1;
    const otherIdx = sixIdx === 0 ? 1 : 0;
    const neededDist = dice.values[otherIdx];

    for (const opp of allPlayers) {
      if (areTeammates(activePlayer.color, opp.color, config)) continue;
      for (const oppToken of opp.tokens) {
        const dist = 6 - oppToken.homeColumnDepth;
        if (oppToken.zone === "homeColumn" && oppToken.homeColumnColor === opp.color && dist === neededDist) {
          for (const myToken of activePlayer.tokens) {
            if (myToken.zone === "finished") continue;
            moves.push({
              tokenId: myToken.id,
              moveType: "gharWaliUltiKuti",
              diceUsedIndices: [sixIdx, otherIdx],
              totalSteps: 6 + neededDist,
              targetTokenId: oppToken.id,
              targetHomeColor: opp.color,
              targetHomeDepth: oppToken.homeColumnDepth,
              description: `6+${neededDist} Ghar Wali Ulti Kuti on ${opp.name}`,
            });
          }
        }
      }
    }
  }

  // 2. Single-die moves
  for (const idx of unused) {
    const steps = dice.values[idx];
    for (const token of activePlayer.tokens) {
      if (token.zone === "finished") continue;
      if (token.zone === "yard") {
        if (
          (config.openRule === "sixOnly" && steps === 6) ||
          (config.openRule === "oneOrSix" && (steps === 6 || steps === 1))
        ) {
          moves.push({
            tokenId: token.id,
            moveType: "openFromYard",
            diceUsedIndices: [idx],
            totalSteps: steps,
            description: `Open ${token.id} on ${steps}`,
          });
        }
      } else if (token.isKuti) {
        moves.push({
          tokenId: token.id,
          moveType: "reverseKutiAdvance",
          diceUsedIndices: [idx],
          totalSteps: steps,
          description: `Reverse Kuti ${token.id} moves ${steps} anti-clockwise`,
        });
      } else if (token.zone === "homeColumn") {
        const nextDepth = token.homeColumnDepth + steps;
        if (nextDepth <= 6) {
          moves.push({
            tokenId: token.id,
            moveType: nextDepth === 6 ? "finishToken" : "homeColumnAdvance",
            diceUsedIndices: [idx],
            totalSteps: steps,
            description: nextDepth === 6 ? `Finish ${token.id}` : `Advance home ${token.id}`,
          });
        }
      } else {
        const nextProg = token.progressSteps + steps;
        if (nextProg <= 50) {
          moves.push({
            tokenId: token.id,
            moveType: "normalAdvance",
            diceUsedIndices: [idx],
            totalSteps: steps,
            description: `Move ${token.id} ${steps} steps`,
          });
        } else if (nextProg - 50 <= 6) {
          const depth = nextProg - 50;
          moves.push({
            tokenId: token.id,
            moveType: depth === 6 ? "finishToken" : "homeColumnAdvance",
            diceUsedIndices: [idx],
            totalSteps: steps,
            description: depth === 6 ? `Finish ${token.id}` : `Enter home lane depth ${depth}`,
          });
        }
      }
    }
  }

  return moves;
}

export function executeServerMove(
  activePlayer: PlayerState,
  allPlayers: PlayerState[],
  move: LegalMove,
  config: LudoRulesConfig
): { updatedPlayers: PlayerState[]; triggeredUltiKuti: boolean; grantBonusTurn: boolean; winnerColor: PlayerColor | null } {
  const players: PlayerState[] = structuredClone(allPlayers);
  const me = players.find((p) => p.playerId === activePlayer.playerId)!;
  const token = me.tokens.find((t) => t.id === move.tokenId)!;
  const prevTile = token.zone === "mainTrack" ? token.mainTrackIndex : -1;
  let triggeredUltiKuti = false;
  let grantBonusTurn = false;

  if (move.moveType === "gharWaliUltiKuti") {
    const opp = players.find((p) => p.color === move.targetHomeColor)!;
    const victim = opp.tokens.find((t) => t.id === move.targetTokenId)!;
    victim.zone = "yard";
    victim.mainTrackIndex = -1;
    victim.progressSteps = -1;
    victim.homeColumnColor = null;
    victim.homeColumnDepth = 0;
    victim.isKuti = false;

    token.zone = "homeColumn";
    token.mainTrackIndex = -1;
    token.progressSteps = 1;
    token.homeColumnColor = move.targetHomeColor ?? null;
    token.homeColumnDepth = move.targetHomeDepth ?? 1;
    token.isKuti = true;
    me.kutiCount += 1;
    triggeredUltiKuti = true;
    grantBonusTurn = true;
  } else if (move.moveType === "openFromYard") {
    token.zone = "mainTrack";
    token.mainTrackIndex = START_TILE[me.color];
    token.progressSteps = 0;
    token.isKuti = false;
  } else if (move.moveType === "reverseKutiAdvance") {
    let cur = token.zone === "homeColumn" && token.homeColumnColor ? HOME_GATE[token.homeColumnColor] : token.mainTrackIndex;
    const stepsLeft = token.zone === "homeColumn" ? move.totalSteps - 1 : move.totalSteps;
    for (let s = 1; s <= stepsLeft; s++) {
      cur = (cur - 1 + 52) % 52;
      if (config.kutiKillScope === "sweepKill" || s === stepsLeft) {
        if (config.kutiBypassSafeZones || !isSafeTile(cur, config)) {
          for (const opp of players) {
            if (areTeammates(me.color, opp.color, config)) continue;
            for (const ot of opp.tokens) {
              if (ot.zone === "mainTrack" && ot.mainTrackIndex === cur) {
                ot.zone = "yard";
                ot.mainTrackIndex = -1;
                ot.progressSteps = -1;
                ot.isKuti = false;
                me.killsCount += 1;
                grantBonusTurn = true;
              }
            }
          }
        }
      }
    }
    token.zone = "mainTrack";
    token.mainTrackIndex = cur;
    token.homeColumnColor = null;
    token.homeColumnDepth = 0;
    token.isKuti = true;
  } else if (move.moveType === "normalAdvance") {
    const nextTile = (token.mainTrackIndex + move.totalSteps) % 52;
    token.mainTrackIndex = nextTile;
    token.progressSteps = (token.progressSteps + move.totalSteps) % 52;
    if (!isSafeTile(nextTile, config)) {
      for (const opp of players) {
        if (areTeammates(me.color, opp.color, config)) continue;
        const oppStack = opp.tokens.filter((t) => t.zone === "mainTrack" && t.mainTrackIndex === nextTile);
        if (oppStack.length === 3 && config.tiggiRule === "delayedRemainingKill") continue;
        for (const ot of oppStack) {
          if (ot.isKuti && !config.kutiVulnerable) continue;
          ot.zone = "yard";
          ot.mainTrackIndex = -1;
          ot.progressSteps = -1;
          ot.isKuti = false;
          me.killsCount += 1;
          grantBonusTurn = true;
        }
      }
    }
  } else if (move.moveType === "homeColumnAdvance") {
    const depth = token.zone === "homeColumn" ? token.homeColumnDepth + move.totalSteps : token.progressSteps + move.totalSteps - 50;
    token.zone = "homeColumn";
    token.mainTrackIndex = -1;
    token.homeColumnColor = me.color;
    token.homeColumnDepth = depth;
  } else if (move.moveType === "finishToken") {
    token.zone = "finished";
    token.mainTrackIndex = -1;
    token.progressSteps = 56;
    token.homeColumnColor = me.color;
    token.homeColumnDepth = 6;
    token.isKuti = false;
    grantBonusTurn = true;
  }

  // Tiggi Delayed Remaining Kill check on previous tile
  if (prevTile !== -1 && !isSafeTile(prevTile, config) && config.tiggiRule === "delayedRemainingKill") {
    const leftBehind = me.tokens.filter((t) => t.zone === "mainTrack" && t.mainTrackIndex === prevTile);
    if (leftBehind.length > 0 && leftBehind.length < 3) {
      const oppHasJota = players.some(
        (opp) =>
          !areTeammates(me.color, opp.color, config) &&
          opp.tokens.filter((t) => t.zone === "mainTrack" && t.mainTrackIndex === prevTile).length >= 2
      );
      if (oppHasJota) {
        for (const victim of leftBehind) {
          victim.zone = "yard";
          victim.mainTrackIndex = -1;
          victim.progressSteps = -1;
          victim.isKuti = false;
        }
      }
    }
  }

  const finishedNow = me.tokens.filter((t) => t.zone === "finished").length;
  const winnerColor = finishedNow >= config.winningTokensCount ? me.color : null;
  return { updatedPlayers: players, triggeredUltiKuti, grantBonusTurn, winnerColor };
}
