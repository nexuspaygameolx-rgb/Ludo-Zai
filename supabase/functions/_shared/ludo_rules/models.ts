export type PlayerColor = "red" | "green" | "yellow" | "blue";
export type TokenZone = "yard" | "mainTrack" | "homeColumn" | "finished";

export interface TokenState {
  id: string;
  owner: PlayerColor;
  zone: TokenZone;
  mainTrackIndex: number;
  progressSteps: number;
  homeColumnColor: PlayerColor | null;
  homeColumnDepth: number;
  isKuti: boolean;
}

export interface PlayerState {
  playerId: string;
  name: string;
  color: PlayerColor;
  isBot?: boolean;
  isGeminiAi?: boolean;
  killsCount: number;
  kutiCount: number;
  consecutiveSixes: number;
  tokens: TokenState[];
}

export interface TwinDiceRoll {
  values: number[];
  used: boolean[];
}

export interface LegalMove {
  tokenId: string;
  moveType:
    | "openFromYard"
    | "normalAdvance"
    | "reverseKutiAdvance"
    | "homeColumnAdvance"
    | "finishToken"
    | "gharWaliUltiKuti";
  diceUsedIndices: number[];
  totalSteps: number;
  targetTokenId?: string;
  targetHomeColor?: PlayerColor;
  targetHomeDepth?: number;
  description: string;
}
