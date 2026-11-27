/// Selectable stacking behavior when 3 same-color tokens (Tiggi) meet an opponent Jota.
enum TiggiVsJotaRule {
  /// Safe while all 3 tokens remain stacked; the moment 1 token or 1 Jota moves out,
  /// the opponent's Jota immediately captures the remaining token(s).
  delayedRemainingKill,

  /// Opponent's Jota immediately captures all 3 tokens upon landing.
  fullTiggiCut,

  /// 3 stacked tokens are immune to opponent Jota (only Ulti Kuti can capture them).
  tiggiShield,
}

/// Kill behavior of an Ulti Kuti token moving in reverse.
enum KutiKillScope {
  /// Captures every opponent token passed along the reverse path as well as landing tile.
  sweepKill,

  /// Captures opponent tokens only on the final landing tile.
  landingKill,
}

/// Rule for bringing tokens out of the starting yard.
enum TokenOpenRule {
  sixOnly,
  oneOrSix,
  oneTokenOpenStart,
}

/// User-defined No-Code Custom Rule (Trigger -> Condition -> Action).
class CustomRuleDefinition {
  final String id;
  final String name;
  final String trigger; // 'on_dice_roll' | 'on_home_entry' | 'on_capture' | 'on_stack'
  final String condition; // 'has_finished_token' | 'dice_sum_exact' | 'is_kuti' | 'double_same_dice'
  final int? conditionValue;
  final String action; // 'grant_extra_turn' | 'flip_to_kuti' | 'bypass_safe_zone' | 'skip_next_opponent'
  final bool enabled;

  const CustomRuleDefinition({
    required this.id,
    required this.name,
    required this.trigger,
    required this.condition,
    this.conditionValue,
    required this.action,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'trigger': trigger,
        'condition': condition,
        'conditionValue': conditionValue,
        'action': action,
        'enabled': enabled,
      };

  factory CustomRuleDefinition.fromJson(Map<String, dynamic> json) {
    return CustomRuleDefinition(
      id: json['id'] as String? ?? 'custom_1',
      name: json['name'] as String? ?? 'Custom Rule',
      trigger: json['trigger'] as String? ?? 'on_capture',
      condition: json['condition'] as String? ?? 'has_finished_token',
      conditionValue: json['conditionValue'] as int?,
      action: json['action'] as String? ?? 'grant_extra_turn',
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

/// Complete switch-based Desi & Classic Ludo rule configuration.
class LudoRulesConfig {
  /// Master switch: ON = Twin Dice (2 dice) + Ghar Wali Ulti Kuti active; OFF = 1 Die standard.
  final bool kutiMode;

  /// When kutiMode is ON and a player has 3 tokens finished (1 token remaining), lock to 1 Die.
  final bool autoSingleDiceOnLastToken;

  /// Sweep vs Landing kill for reverse-moving Kuti tokens.
  final KutiKillScope kutiKillScope;

  /// Whether Kuti bypasses Star and Colored safe zones.
  final bool kutiBypassSafeZones;

  /// Whether a stationary Kuti on a non-safe tile can be captured by normal tokens/Jota.
  final bool kutiVulnerable;

  /// Jota (2 same-color tokens) protection enabled.
  final bool jotaEnabled;

  /// 3 same-color tokens (Tiggi) vs opponent Jota behavior.
  final TiggiVsJotaRule tiggiRule;

  /// Mandatory capture before a player's tokens can enter their home column.
  final bool katiBaghairGharBand;

  /// Forfeit turn on three consecutive 6s (or three consecutive 6+6 in twin-dice mode).
  final bool tripleSixForfeit;

  /// Token yard exit rule.
  final TokenOpenRule openRule;

  /// 8 safe tiles (4 colored starts + 4 stars) vs 4 safe tiles (4 colored starts only).
  final int safeZoneCount;

  /// Tokens required to finish to win (4 = Full, 2 = Quick, 1 = Blitz).
  final int winningTokensCount;

  /// 2v2 Team-Up Jodi mode (opposite seats partner up; Kuti & captures ignore partner).
  final bool teamMode2v2;

  /// Dynamic user-created rules attached to this room.
  final List<CustomRuleDefinition> customRules;

  const LudoRulesConfig({
    this.kutiMode = true,
    this.autoSingleDiceOnLastToken = true,
    this.kutiKillScope = KutiKillScope.sweepKill,
    this.kutiBypassSafeZones = true,
    this.kutiVulnerable = true,
    this.jotaEnabled = true,
    this.tiggiRule = TiggiVsJotaRule.delayedRemainingKill,
    this.katiBaghairGharBand = false,
    this.tripleSixForfeit = true,
    this.openRule = TokenOpenRule.sixOnly,
    this.safeZoneCount = 8,
    this.winningTokensCount = 4,
    this.teamMode2v2 = false,
    this.customRules = const [],
  });

  /// Regional Preset: Punjab Kuti Special
  factory LudoRulesConfig.punjabKutiSpecial() => const LudoRulesConfig(
        kutiMode: true,
        autoSingleDiceOnLastToken: true,
        kutiKillScope: KutiKillScope.sweepKill,
        kutiBypassSafeZones: true,
        kutiVulnerable: true,
        jotaEnabled: true,
        tiggiRule: TiggiVsJotaRule.delayedRemainingKill,
        katiBaghairGharBand: false,
        tripleSixForfeit: true,
        openRule: TokenOpenRule.sixOnly,
        safeZoneCount: 8,
        winningTokensCount: 4,
      );

  /// Regional Preset: Karachi / Sindh Master
  factory LudoRulesConfig.sindhMaster() => const LudoRulesConfig(
        kutiMode: false,
        jotaEnabled: true,
        tiggiRule: TiggiVsJotaRule.fullTiggiCut,
        katiBaghairGharBand: true,
        openRule: TokenOpenRule.oneTokenOpenStart,
        safeZoneCount: 8,
        winningTokensCount: 4,
      );

  /// Classic Ludo STAR Preset
  factory LudoRulesConfig.classicLudoStar() => const LudoRulesConfig(
        kutiMode: false,
        jotaEnabled: false,
        katiBaghairGharBand: false,
        openRule: TokenOpenRule.sixOnly,
        safeZoneCount: 8,
        winningTokensCount: 4,
      );

  LudoRulesConfig copyWith({
    bool? kutiMode,
    bool? autoSingleDiceOnLastToken,
    KutiKillScope? kutiKillScope,
    bool? kutiBypassSafeZones,
    bool? kutiVulnerable,
    bool? jotaEnabled,
    TiggiVsJotaRule? tiggiRule,
    bool? katiBaghairGharBand,
    bool? tripleSixForfeit,
    TokenOpenRule? openRule,
    int? safeZoneCount,
    int? winningTokensCount,
    bool? teamMode2v2,
    List<CustomRuleDefinition>? customRules,
  }) {
    return LudoRulesConfig(
      kutiMode: kutiMode ?? this.kutiMode,
      autoSingleDiceOnLastToken:
          autoSingleDiceOnLastToken ?? this.autoSingleDiceOnLastToken,
      kutiKillScope: kutiKillScope ?? this.kutiKillScope,
      kutiBypassSafeZones: kutiBypassSafeZones ?? this.kutiBypassSafeZones,
      kutiVulnerable: kutiVulnerable ?? this.kutiVulnerable,
      jotaEnabled: jotaEnabled ?? this.jotaEnabled,
      tiggiRule: tiggiRule ?? this.tiggiRule,
      katiBaghairGharBand: katiBaghairGharBand ?? this.katiBaghairGharBand,
      tripleSixForfeit: tripleSixForfeit ?? this.tripleSixForfeit,
      openRule: openRule ?? this.openRule,
      safeZoneCount: safeZoneCount ?? this.safeZoneCount,
      winningTokensCount: winningTokensCount ?? this.winningTokensCount,
      teamMode2v2: teamMode2v2 ?? this.teamMode2v2,
      customRules: customRules ?? this.customRules,
    );
  }

  Map<String, dynamic> toJson() => {
        'kutiMode': kutiMode,
        'autoSingleDiceOnLastToken': autoSingleDiceOnLastToken,
        'kutiKillScope': kutiKillScope.name,
        'kutiBypassSafeZones': kutiBypassSafeZones,
        'kutiVulnerable': kutiVulnerable,
        'jotaEnabled': jotaEnabled,
        'tiggiRule': tiggiRule.name,
        'katiBaghairGharBand': katiBaghairGharBand,
        'tripleSixForfeit': tripleSixForfeit,
        'openRule': openRule.name,
        'safeZoneCount': safeZoneCount,
        'winningTokensCount': winningTokensCount,
        'teamMode2v2': teamMode2v2,
        'customRules': customRules.map((e) => e.toJson()).toList(),
      };

  factory LudoRulesConfig.fromJson(Map<String, dynamic> json) {
    return LudoRulesConfig(
      kutiMode: json['kutiMode'] as bool? ?? true,
      autoSingleDiceOnLastToken:
          json['autoSingleDiceOnLastToken'] as bool? ?? true,
      kutiKillScope: KutiKillScope.values.firstWhere(
        (e) => e.name == json['kutiKillScope'],
        orElse: () => KutiKillScope.sweepKill,
      ),
      kutiBypassSafeZones: json['kutiBypassSafeZones'] as bool? ?? true,
      kutiVulnerable: json['kutiVulnerable'] as bool? ?? true,
      jotaEnabled: json['jotaEnabled'] as bool? ?? true,
      tiggiRule: TiggiVsJotaRule.values.firstWhere(
        (e) => e.name == json['tiggiRule'],
        orElse: () => TiggiVsJotaRule.delayedRemainingKill,
      ),
      katiBaghairGharBand: json['katiBaghairGharBand'] as bool? ?? false,
      tripleSixForfeit: json['tripleSixForfeit'] as bool? ?? true,
      openRule: TokenOpenRule.values.firstWhere(
        (e) => e.name == json['openRule'],
        orElse: () => TokenOpenRule.sixOnly,
      ),
      safeZoneCount: json['safeZoneCount'] as int? ?? 8,
      winningTokensCount: json['winningTokensCount'] as int? ?? 4,
      teamMode2v2: json['teamMode2v2'] as bool? ?? false,
      customRules: (json['customRules'] as List<dynamic>? ?? [])
          .map((e) => CustomRuleDefinition.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
