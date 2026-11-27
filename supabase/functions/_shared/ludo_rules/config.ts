export type TiggiVsJotaRule = "delayedRemainingKill" | "fullTiggiCut" | "tiggiShield";
export type KutiKillScope = "sweepKill" | "landingKill";
export type TokenOpenRule = "sixOnly" | "oneOrSix" | "oneTokenOpenStart";

export interface CustomRuleDefinition {
  id: string;
  name: string;
  trigger: string;
  condition: string;
  conditionValue?: number;
  action: string;
  enabled: boolean;
}

export interface LudoRulesConfig {
  kutiMode: boolean;
  autoSingleDiceOnLastToken: boolean;
  kutiKillScope: KutiKillScope;
  kutiBypassSafeZones: boolean;
  kutiVulnerable: boolean;
  jotaEnabled: boolean;
  tiggiRule: TiggiVsJotaRule;
  katiBaghairGharBand: boolean;
  tripleSixForfeit: boolean;
  openRule: TokenOpenRule;
  safeZoneCount: number;
  winningTokensCount: number;
  teamMode2v2: boolean;
  customRules: CustomRuleDefinition[];
}

export const DEFAULT_KUTI_CONFIG: LudoRulesConfig = {
  kutiMode: true,
  autoSingleDiceOnLastToken: true,
  kutiKillScope: "sweepKill",
  kutiBypassSafeZones: true,
  kutiVulnerable: true,
  jotaEnabled: true,
  tiggiRule: "delayedRemainingKill",
  katiBaghairGharBand: false,
  tripleSixForfeit: true,
  openRule: "sixOnly",
  safeZoneCount: 8,
  winningTokensCount: 4,
  teamMode2v2: false,
  customRules: [],
};
