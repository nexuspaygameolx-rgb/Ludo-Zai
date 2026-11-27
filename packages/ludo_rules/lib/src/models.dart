import 'config.dart';

enum PlayerColor { red, green, yellow, blue }

enum TokenZone {
  yard,
  mainTrack,
  homeColumn,
  finished,
}

class TokenState {
  final String id; // e.g. 'red_0'
  final PlayerColor owner;
  final TokenZone zone;

  /// 0..51 absolute main track index when in [TokenZone.mainTrack].
  final int mainTrackIndex;

  /// Steps walked since leaving start (0..50 for main track, 51..55 for home column, 56 = finished).
  final int progressSteps;

  /// When in [TokenZone.homeColumn], which color's home column it occupies (usually owner,
  /// or an opponent's home column at the exact moment of executing a Ghar Wali Ulti Kuti).
  final PlayerColor? homeColumnColor;

  /// 1..5 depth inside home column (5 = 1 step before triangle, 1 = 5 steps before triangle;
  /// distanceToFinish = 6 - homeColumnDepth).
  final int homeColumnDepth;

  /// True once this token has captured an opponent inside their home column via 6+X Kuti.
  /// Moves strictly anti-clockwise (reverse) for the rest of its lifecycle until finished or captured.
  final bool isKuti;

  const TokenState({
    required this.id,
    required this.owner,
    this.zone = TokenZone.yard,
    this.mainTrackIndex = -1,
    this.progressSteps = -1,
    this.homeColumnColor,
    this.homeColumnDepth = 0,
    this.isKuti = false,
  });

  bool get isFinished => zone == TokenZone.finished;
  bool get isInYard => zone == TokenZone.yard;
  bool get isInHomeColumn => zone == TokenZone.homeColumn;
  int get distanceToFinish => zone == TokenZone.homeColumn ? (6 - homeColumnDepth) : -1;

  TokenState copyWith({
    TokenZone? zone,
    int? mainTrackIndex,
    int? progressSteps,
    PlayerColor? homeColumnColor,
    int? homeColumnDepth,
    bool? isKuti,
  }) {
    return TokenState(
      id: id,
      owner: owner,
      zone: zone ?? this.zone,
      mainTrackIndex: mainTrackIndex ?? this.mainTrackIndex,
      progressSteps: progressSteps ?? this.progressSteps,
      homeColumnColor: homeColumnColor ?? this.homeColumnColor,
      homeColumnDepth: homeColumnDepth ?? this.homeColumnDepth,
      isKuti: isKuti ?? this.isKuti,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner': owner.name,
        'zone': zone.name,
        'mainTrackIndex': mainTrackIndex,
        'progressSteps': progressSteps,
        'homeColumnColor': homeColumnColor?.name,
        'homeColumnDepth': homeColumnDepth,
        'isKuti': isKuti,
      };

  factory TokenState.fromJson(Map<String, dynamic> json) {
    return TokenState(
      id: json['id'] as String,
      owner: PlayerColor.values.firstWhere((e) => e.name == json['owner']),
      zone: TokenZone.values.firstWhere((e) => e.name == json['zone']),
      mainTrackIndex: json['mainTrackIndex'] as int? ?? -1,
      progressSteps: json['progressSteps'] as int? ?? -1,
      homeColumnColor: json['homeColumnColor'] != null
          ? PlayerColor.values.firstWhere((e) => e.name == json['homeColumnColor'])
          : null,
      homeColumnDepth: json['homeColumnDepth'] as int? ?? 0,
      isKuti: json['isKuti'] as bool? ?? false,
    );
  }
}

class PlayerState {
  final String playerId;
  final String name;
  final PlayerColor color;
  final bool isBot;
  final bool isGeminiAi;
  final int killsCount;
  final int kutiCount;
  final int consecutiveSixes;
  final List<TokenState> tokens;

  const PlayerState({
    required this.playerId,
    required this.name,
    required this.color,
    this.isBot = false,
    this.isGeminiAi = false,
    this.killsCount = 0,
    this.kutiCount = 0,
    this.consecutiveSixes = 0,
    required this.tokens,
  });

  int get finishedCount => tokens.where((t) => t.isFinished).length;
  int get remainingTokensCount => 4 - finishedCount;
  bool get hasAtLeastOneFinished => finishedCount >= 1;
  bool get hasAtLeastOneKill => (killsCount + kutiCount) >= 1;

  PlayerState copyWith({
    String? name,
    bool? isBot,
    bool? isGeminiAi,
    int? killsCount,
    int? kutiCount,
    int? consecutiveSixes,
    List<TokenState>? tokens,
  }) {
    return PlayerState(
      playerId: playerId,
      name: name ?? this.name,
      color: color,
      isBot: isBot ?? this.isBot,
      isGeminiAi: isGeminiAi ?? this.isGeminiAi,
      killsCount: killsCount ?? this.killsCount,
      kutiCount: kutiCount ?? this.kutiCount,
      consecutiveSixes: consecutiveSixes ?? this.consecutiveSixes,
      tokens: tokens ?? this.tokens,
    );
  }

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'name': name,
        'color': color.name,
        'isBot': isBot,
        'isGeminiAi': isGeminiAi,
        'killsCount': killsCount,
        'kutiCount': kutiCount,
        'consecutiveSixes': consecutiveSixes,
        'tokens': tokens.map((t) => t.toJson()).toList(),
      };

  factory PlayerState.fromJson(Map<String, dynamic> json) {
    return PlayerState(
      playerId: json['playerId'] as String,
      name: json['name'] as String,
      color: PlayerColor.values.firstWhere((e) => e.name == json['color']),
      isBot: json['isBot'] as bool? ?? false,
      isGeminiAi: json['isGeminiAi'] as bool? ?? false,
      killsCount: json['killsCount'] as int? ?? 0,
      kutiCount: json['kutiCount'] as int? ?? 0,
      consecutiveSixes: json['consecutiveSixes'] as int? ?? 0,
      tokens: (json['tokens'] as List<dynamic>)
          .map((e) => TokenState.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

enum MoveType {
  openFromYard,
  normalAdvance,
  reverseKutiAdvance,
  homeColumnAdvance,
  finishToken,
  gharWaliUltiKuti, // 6 + X capture inside opponent's home column
}

class LegalMove {
  final String tokenId;
  final MoveType moveType;
  final List<int> diceUsedIndices; // indices into activeDiceValues
  final int totalSteps;
  final String? targetTokenId; // for gharWaliUltiKuti or direct capture
  final PlayerColor? targetHomeColor;
  final int? targetHomeDepth;
  final String description;

  const LegalMove({
    required this.tokenId,
    required this.moveType,
    required this.diceUsedIndices,
    required this.totalSteps,
    this.targetTokenId,
    this.targetHomeColor,
    this.targetHomeDepth,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'tokenId': tokenId,
        'moveType': moveType.name,
        'diceUsedIndices': diceUsedIndices,
        'totalSteps': totalSteps,
        'targetTokenId': targetTokenId,
        'targetHomeColor': targetHomeColor?.name,
        'targetHomeDepth': targetHomeDepth,
        'description': description,
      };
}

class MoveExecutionResult {
  final List<PlayerState> updatedPlayers;
  final List<String> capturedTokenIds;
  final bool triggeredUltiKuti;
  final bool triggeredDelayedTiggiKill;
  final bool grantBonusTurn;
  final PlayerColor? winnerColor;
  final String eventSummary;

  const MoveExecutionResult({
    required this.updatedPlayers,
    this.capturedTokenIds = const [],
    this.triggeredUltiKuti = false,
    this.triggeredDelayedTiggiKill = false,
    this.grantBonusTurn = false,
    this.winnerColor,
    required this.eventSummary,
  });
}
