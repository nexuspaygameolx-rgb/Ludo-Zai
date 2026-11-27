import 'config.dart';
import 'dice.dart';
import 'models.dart';

/// Deterministic, zero-loophole Desi Kuti Ludo rule engine.
class LudoRuleEngine {
  static const int mainTrackLength = 52;
  static const int homeColumnLength = 5; // depths 1..5, finish at 6

  /// Starting main-track index (0..51) for each player color.
  static const Map<PlayerColor, int> startTileIndex = {
    PlayerColor.red: 0,
    PlayerColor.green: 13,
    PlayerColor.yellow: 26,
    PlayerColor.blue: 39,
  };

  /// Home-entry gate index (last main-track tile before entering own home column).
  static const Map<PlayerColor, int> homeGateIndex = {
    PlayerColor.red: 50,
    PlayerColor.green: 11,
    PlayerColor.yellow: 24,
    PlayerColor.blue: 37,
  };

  /// 4 Colored start squares + 4 Star squares.
  static const Set<int> eightSafeTiles = {0, 8, 13, 21, 26, 34, 39, 47};
  static const Set<int> fourSafeTiles = {0, 13, 26, 39};

  static bool isSafeTile(int trackIndex, LudoRulesConfig config) {
    if (config.safeZoneCount <= 4) {
      return fourSafeTiles.contains(trackIndex);
    }
    return eightSafeTiles.contains(trackIndex);
  }

  /// Checks if two colors are partners in 2v2 Team Mode (Red+Yellow vs Green+Blue).
  static bool areTeammates(PlayerColor a, PlayerColor b, LudoRulesConfig config) {
    if (a == b) return true;
    if (!config.teamMode2v2) return false;
    return (a == PlayerColor.red && b == PlayerColor.yellow) ||
        (a == PlayerColor.yellow && b == PlayerColor.red) ||
        (a == PlayerColor.green && b == PlayerColor.blue) ||
        (a == PlayerColor.blue && b == PlayerColor.green);
  }

  /// Generates all legal moves for [activePlayer] given the current [dice] state.
  static List<LegalMove> getLegalMoves({
    required PlayerState activePlayer,
    required List<PlayerState> allPlayers,
    required TwinDiceRoll dice,
    required LudoRulesConfig config,
  }) {
    final moves = <LegalMove>[];
    final unusedIndices = <int>[];
    for (int i = 0; i < dice.values.length; i++) {
      if (!dice.used[i]) unusedIndices.add(i);
    }
    if (unusedIndices.isEmpty) return moves;

    // 1. Ghar Wali Ulti Kuti (6 + X) when Kuti Mode is ON, both dice unused,
    // one die is 6, and activePlayer has finished at least 1 token.
    if (config.kutiMode &&
        unusedIndices.length == 2 &&
        activePlayer.hasAtLeastOneFinished &&
        dice.values.contains(6)) {
      final sixIdx = dice.values[0] == 6 ? 0 : 1;
      final otherIdx = sixIdx == 0 ? 1 : 0;
      final neededDistance = dice.values[otherIdx];

      for (final opp in allPlayers) {
        if (areTeammates(activePlayer.color, opp.color, config)) continue;
        for (final oppToken in opp.tokens) {
          if (oppToken.zone == TokenZone.homeColumn &&
              oppToken.homeColumnColor == opp.color &&
              oppToken.distanceToFinish == neededDistance) {
            for (final myToken in activePlayer.tokens) {
              if (myToken.isFinished) continue;
              moves.add(LegalMove(
                tokenId: myToken.id,
                moveType: MoveType.gharWaliUltiKuti,
                diceUsedIndices: [sixIdx, otherIdx],
                totalSteps: 6 + neededDistance,
                targetTokenId: oppToken.id,
                targetHomeColor: opp.color,
                targetHomeDepth: oppToken.homeColumnDepth,
                description:
                    '6+$neededDistance Ghar Wali Ulti Kuti on ${opp.name} (${oppToken.id})',
              ));
            }
          }
        }
      }
    }

    // 2. Single-die moves for each unused die
    for (final dieIdx in unusedIndices) {
      final steps = dice.values[dieIdx];
      for (final token in activePlayer.tokens) {
        if (token.isFinished) continue;
        final singleMove = _evaluateTokenMove(
          token: token,
          activePlayer: activePlayer,
          allPlayers: allPlayers,
          steps: steps,
          diceIndices: [dieIdx],
          config: config,
        );
        if (singleMove != null) {
          moves.add(singleMove);
        }
      }
    }

    // 3. Combined two-dice move on a single token (when 2 dice remain unused)
    if (unusedIndices.length == 2) {
      final combinedSteps = dice.values[0] + dice.values[1];
      for (final token in activePlayer.tokens) {
        if (token.isFinished || token.isInYard) continue;
        final combinedMove = _evaluateTokenMove(
          token: token,
          activePlayer: activePlayer,
          allPlayers: allPlayers,
          steps: combinedSteps,
          diceIndices: [0, 1],
          config: config,
        );
        if (combinedMove != null) {
          moves.add(combinedMove);
        }
      }
    }

    return moves;
  }

  static LegalMove? _evaluateTokenMove({
    required TokenState token,
    required PlayerState activePlayer,
    required List<PlayerState> allPlayers,
    required int steps,
    required List<int> diceIndices,
    required LudoRulesConfig config,
  }) {
    if (token.isInYard) {
      final canOpen = (config.openRule == TokenOpenRule.sixOnly && steps == 6) ||
          (config.openRule == TokenOpenRule.oneOrSix && (steps == 6 || steps == 1));
      if (!canOpen) return null;
      return LegalMove(
        tokenId: token.id,
        moveType: MoveType.openFromYard,
        diceUsedIndices: diceIndices,
        totalSteps: steps,
        description: 'Open ${token.id} on $steps',
      );
    }

    if (token.isInHomeColumn) {
      if (token.homeColumnColor != null && token.homeColumnColor != token.owner) {
        return LegalMove(
          tokenId: token.id,
          moveType: MoveType.reverseKutiAdvance,
          diceUsedIndices: diceIndices,
          totalSteps: steps,
          description: 'Exit opponent home column in reverse ($steps steps)',
        );
      }

      final nextDepth = token.homeColumnDepth + steps;
      if (nextDepth > homeColumnLength + 1) return null;
      if (nextDepth == homeColumnLength + 1) {
        return LegalMove(
          tokenId: token.id,
          moveType: MoveType.finishToken,
          diceUsedIndices: diceIndices,
          totalSteps: steps,
          description: 'Finish ${token.id} home!',
        );
      }
      return LegalMove(
        tokenId: token.id,
        moveType: MoveType.homeColumnAdvance,
        diceUsedIndices: diceIndices,
        totalSteps: steps,
        description: 'Advance ${token.id} inside home lane ($steps steps)',
      );
    }

    if (token.isKuti) {
      final gate = homeGateIndex[token.owner]!;
      final distToGateReverse = (token.mainTrackIndex - gate + mainTrackLength) % mainTrackLength;
      if (token.progressSteps >= 26 && steps > distToGateReverse) {
        final homeSteps = steps - distToGateReverse;
        if (homeSteps > homeColumnLength + 1) return null;
        if (homeSteps == homeColumnLength + 1) {
          return LegalMove(
            tokenId: token.id,
            moveType: MoveType.finishToken,
            diceUsedIndices: diceIndices,
            totalSteps: steps,
            description: 'Reverse Kuti ${token.id} finishes home!',
          );
        }
        return LegalMove(
          tokenId: token.id,
          moveType: MoveType.homeColumnAdvance,
          diceUsedIndices: diceIndices,
          totalSteps: steps,
          description: 'Reverse Kuti ${token.id} enters home lane',
        );
      }
      return LegalMove(
        tokenId: token.id,
        moveType: MoveType.reverseKutiAdvance,
        diceUsedIndices: diceIndices,
        totalSteps: steps,
        description: 'Reverse Kuti ${token.id} moves $steps anti-clockwise',
      );
    } else {
      final nextProgress = token.progressSteps + steps;
      if (nextProgress > 50) {
        if (config.katiBaghairGharBand && !activePlayer.hasAtLeastOneKill) {
          return LegalMove(
            tokenId: token.id,
            moveType: MoveType.normalAdvance,
            diceUsedIndices: diceIndices,
            totalSteps: steps,
            description: 'Extra lap (Kati Baghair Ghar Band active)',
          );
        }
        final homeDepth = nextProgress - 50;
        if (homeDepth > homeColumnLength + 1) return null;
        if (homeDepth == homeColumnLength + 1) {
          return LegalMove(
            tokenId: token.id,
            moveType: MoveType.finishToken,
            diceUsedIndices: diceIndices,
            totalSteps: steps,
            description: 'Finish ${token.id} home!',
          );
        }
        return LegalMove(
          tokenId: token.id,
          moveType: MoveType.homeColumnAdvance,
          diceUsedIndices: diceIndices,
          totalSteps: steps,
          description: 'Enter home lane depth $homeDepth',
        );
      }

      final targetTile = (token.mainTrackIndex + steps) % mainTrackLength;
      if (!isSafeTile(targetTile, config)) {
        final tileCheck = _canLandOnTile(
          attackerColor: token.owner,
          targetTile: targetTile,
          allPlayers: allPlayers,
          config: config,
        );
        if (!tileCheck) return null;
      }

      return LegalMove(
        tokenId: token.id,
        moveType: MoveType.normalAdvance,
        diceUsedIndices: diceIndices,
        totalSteps: steps,
        description: 'Move ${token.id} clockwise $steps steps',
      );
    }
  }

  static bool _canLandOnTile({
    required PlayerColor attackerColor,
    required int targetTile,
    required List<PlayerState> allPlayers,
    required LudoRulesConfig config,
  }) {
    if (!config.jotaEnabled) return true;

    final ownTokensOnTarget = allPlayers
        .firstWhere((p) => p.color == attackerColor)
        .tokens
        .where((t) => t.zone == TokenZone.mainTrack && t.mainTrackIndex == targetTile)
        .length;
    final incomingStackSize = ownTokensOnTarget + 1;

    for (final opp in allPlayers) {
      if (areTeammates(attackerColor, opp.color, config)) continue;
      final oppTokens = opp.tokens
          .where((t) => t.zone == TokenZone.mainTrack && t.mainTrackIndex == targetTile)
          .toList();
      if (oppTokens.length == 2) {
        if (incomingStackSize < 2) return false;
      } else if (oppTokens.length >= 3) {
        if (config.tiggiRule == TiggiVsJotaRule.tiggiShield) {
          return false;
        }
        if (incomingStackSize < 2) return false;
      }
    }
    return true;
  }

  /// Executes a validated [LegalMove], evaluates any user-created [CustomRuleDefinition]s,
  /// and returns the updated state of all players.
  static MoveExecutionResult executeMove({
    required PlayerState activePlayer,
    required List<PlayerState> allPlayers,
    required LegalMove move,
    required LudoRulesConfig config,
  }) {
    final players = allPlayers.map((p) => p.copyWith(tokens: List<TokenState>.from(p.tokens))).toList();
    final meIdx = players.indexWhere((p) => p.playerId == activePlayer.playerId);
    final me = players[meIdx];
    final tokenIdx = me.tokens.indexWhere((t) => t.id == move.tokenId);
    var movingToken = me.tokens[tokenIdx];

    final previousTile = movingToken.zone == TokenZone.mainTrack ? movingToken.mainTrackIndex : -1;
    final capturedIds = <String>[];
    bool triggeredKuti = false;
    bool triggeredDelayedTiggi = false;
    bool bonusTurn = false;
    String summary = move.description;

    if (move.moveType == MoveType.gharWaliUltiKuti) {
      final oppIdx = players.indexWhere((p) => p.color == move.targetHomeColor);
      final opp = players[oppIdx];
      final oppTokens = List<TokenState>.from(opp.tokens);
      final targetIdx = oppTokens.indexWhere((t) => t.id == move.targetTokenId);
      final captured = oppTokens[targetIdx];
      oppTokens[targetIdx] = captured.copyWith(
        zone: TokenZone.yard,
        mainTrackIndex: -1,
        progressSteps: -1,
        homeColumnColor: null,
        homeColumnDepth: 0,
        isKuti: false,
      );
      players[oppIdx] = opp.copyWith(tokens: oppTokens);
      capturedIds.add(captured.id);

      movingToken = movingToken.copyWith(
        zone: TokenZone.homeColumn,
        mainTrackIndex: -1,
        progressSteps: 1,
        homeColumnColor: move.targetHomeColor,
        homeColumnDepth: move.targetHomeDepth ?? 1,
        isKuti: true,
      );
      triggeredKuti = true;
      bonusTurn = true;
      summary = 'ULTI KUTI! ${me.name} captured ${opp.name} inside home column!';
    } else if (move.moveType == MoveType.openFromYard) {
      final startIdx = startTileIndex[me.color]!;
      movingToken = movingToken.copyWith(
        zone: TokenZone.mainTrack,
        mainTrackIndex: startIdx,
        progressSteps: 0,
        isKuti: false,
      );
    } else if (move.moveType == MoveType.reverseKutiAdvance) {
      int currentTile;
      int stepsRemaining = move.totalSteps;
      if (movingToken.isInHomeColumn && movingToken.homeColumnColor != null) {
        final exitGate = homeGateIndex[movingToken.homeColumnColor!]!;
        currentTile = exitGate;
        stepsRemaining -= 1;
        _applyKutiSweepAtTile(
          tile: currentTile,
          attackerColor: me.color,
          players: players,
          capturedIds: capturedIds,
          config: config,
        );
      } else {
        currentTile = movingToken.mainTrackIndex;
      }

      for (int s = 1; s <= stepsRemaining; s++) {
        currentTile = (currentTile - 1 + mainTrackLength) % mainTrackLength;
        final isFinalStep = (s == stepsRemaining);
        if (config.kutiKillScope == KutiKillScope.sweepKill || isFinalStep) {
          _applyKutiSweepAtTile(
            tile: currentTile,
            attackerColor: me.color,
            players: players,
            capturedIds: capturedIds,
            config: config,
          );
        }
      }

      movingToken = movingToken.copyWith(
        zone: TokenZone.mainTrack,
        mainTrackIndex: currentTile,
        progressSteps: (movingToken.progressSteps < 0 ? 0 : movingToken.progressSteps) + move.totalSteps,
        homeColumnColor: null,
        homeColumnDepth: 0,
        isKuti: true,
      );
      if (capturedIds.isNotEmpty) {
        bonusTurn = true;
        summary = 'Reverse Kuti swept ${capturedIds.length} token(s)!';
      }
    } else if (move.moveType == MoveType.normalAdvance) {
      final newTile = (movingToken.mainTrackIndex + move.totalSteps) % mainTrackLength;
      final newProg = (movingToken.progressSteps + move.totalSteps) % mainTrackLength;
      movingToken = movingToken.copyWith(
        zone: TokenZone.mainTrack,
        mainTrackIndex: newTile,
        progressSteps: newProg,
      );

      if (!isSafeTile(newTile, config)) {
        _applyNormalLandingCapture(
          tile: newTile,
          attackerColor: me.color,
          players: players,
          capturedIds: capturedIds,
          config: config,
        );
        if (capturedIds.isNotEmpty) {
          bonusTurn = true;
        }
      }
    } else if (move.moveType == MoveType.homeColumnAdvance) {
      final nextDepth = movingToken.zone == TokenZone.homeColumn
          ? movingToken.homeColumnDepth + move.totalSteps
          : (movingToken.progressSteps + move.totalSteps - 50).clamp(1, homeColumnLength);
      movingToken = movingToken.copyWith(
        zone: TokenZone.homeColumn,
        mainTrackIndex: -1,
        homeColumnColor: me.color,
        homeColumnDepth: nextDepth,
      );
    } else if (move.moveType == MoveType.finishToken) {
      movingToken = movingToken.copyWith(
        zone: TokenZone.finished,
        mainTrackIndex: -1,
        progressSteps: 56,
        homeColumnColor: me.color,
        homeColumnDepth: 6,
        isKuti: false,
      );
      bonusTurn = true;
    }

    // Evaluate user-defined CustomRules (Trigger -> Condition -> Action)
    for (final rule in config.customRules) {
      if (!rule.enabled) continue;
      final triggerMatched =
          (rule.trigger == 'on_capture' && capturedIds.isNotEmpty) ||
          (rule.trigger == 'on_home_entry' && move.moveType == MoveType.homeColumnAdvance) ||
          (rule.trigger == 'on_dice_roll' &&
              (rule.conditionValue == null || move.totalSteps == rule.conditionValue));
      if (!triggerMatched) continue;

      final conditionMatched =
          (rule.condition == 'has_finished_token' && players[meIdx].hasAtLeastOneFinished) ||
          (rule.condition == 'is_kuti' && movingToken.isKuti) ||
          (rule.condition == 'dice_sum_exact' &&
              (rule.conditionValue == null || move.totalSteps == rule.conditionValue));
      if (!conditionMatched) continue;

      if (rule.action == 'grant_extra_turn') {
        bonusTurn = true;
        summary = '${rule.name}: Extra Turn activated!';
      } else if (rule.action == 'flip_to_kuti' && movingToken.zone == TokenZone.mainTrack) {
        movingToken = movingToken.copyWith(isKuti: true);
        summary = '${rule.name}: Token flipped into Reverse Kuti!';
      }
    }

    final updatedMyTokens = List<TokenState>.from(players[meIdx].tokens);
    updatedMyTokens[tokenIdx] = movingToken;
    players[meIdx] = players[meIdx].copyWith(
      tokens: updatedMyTokens,
      killsCount: players[meIdx].killsCount + (triggeredKuti ? 0 : capturedIds.length),
      kutiCount: players[meIdx].kutiCount + (triggeredKuti ? 1 : 0),
    );

    // Delayed Remaining Kill Check on previousTile (Tiggi rule)
    if (previousTile != -1 &&
        !isSafeTile(previousTile, config) &&
        config.tiggiRule == TiggiVsJotaRule.delayedRemainingKill) {
      final leftBehind = players[meIdx]
          .tokens
          .where((t) => t.zone == TokenZone.mainTrack && t.mainTrackIndex == previousTile)
          .toList();
      if (leftBehind.isNotEmpty && leftBehind.length < 3) {
        final hasOppJota = players.any((opp) =>
            !areTeammates(me.color, opp.color, config) &&
            opp.tokens
                    .where((t) => t.zone == TokenZone.mainTrack && t.mainTrackIndex == previousTile)
                    .length >=
                2);
        if (hasOppJota) {
          final cleaned = List<TokenState>.from(players[meIdx].tokens);
          for (final victim in leftBehind) {
            final vIdx = cleaned.indexWhere((t) => t.id == victim.id);
            cleaned[vIdx] = victim.copyWith(
              zone: TokenZone.yard,
              mainTrackIndex: -1,
              progressSteps: -1,
              isKuti: false,
            );
            capturedIds.add(victim.id);
          }
          players[meIdx] = players[meIdx].copyWith(tokens: cleaned);
          triggeredDelayedTiggi = true;
          summary = 'Delayed Tiggi Kill! Remaining token(s) captured by opponent Jota!';
        }
      }
    }

    PlayerColor? winner;
    if (config.teamMode2v2) {
      final teamFinished = players
          .where((p) => areTeammates(me.color, p.color, config))
          .fold<int>(0, (sum, p) => sum + p.finishedCount);
      if (teamFinished >= config.winningTokensCount * 2) {
        winner = me.color;
      }
    } else if (players[meIdx].finishedCount >= config.winningTokensCount) {
      winner = me.color;
    }

    return MoveExecutionResult(
      updatedPlayers: players,
      capturedTokenIds: capturedIds,
      triggeredUltiKuti: triggeredKuti,
      triggeredDelayedTiggiKill: triggeredDelayedTiggi,
      grantBonusTurn: bonusTurn,
      winnerColor: winner,
      eventSummary: summary,
    );
  }

  static void _applyKutiSweepAtTile({
    required int tile,
    required PlayerColor attackerColor,
    required List<PlayerState> players,
    required List<String> capturedIds,
    required LudoRulesConfig config,
  }) {
    if (!config.kutiBypassSafeZones && isSafeTile(tile, config)) return;

    for (int i = 0; i < players.length; i++) {
      final opp = players[i];
      if (areTeammates(attackerColor, opp.color, config)) continue;
      bool changed = false;
      final tokens = List<TokenState>.from(opp.tokens);
      for (int t = 0; t < tokens.length; t++) {
        if (tokens[t].zone == TokenZone.mainTrack && tokens[t].mainTrackIndex == tile) {
          capturedIds.add(tokens[t].id);
          tokens[t] = tokens[t].copyWith(
            zone: TokenZone.yard,
            mainTrackIndex: -1,
            progressSteps: -1,
            homeColumnColor: null,
            homeColumnDepth: 0,
            isKuti: false,
          );
          changed = true;
        }
      }
      if (changed) {
        players[i] = opp.copyWith(tokens: tokens);
      }
    }
  }

  static void _applyNormalLandingCapture({
    required int tile,
    required PlayerColor attackerColor,
    required List<PlayerState> players,
    required List<String> capturedIds,
    required LudoRulesConfig config,
  }) {
    final attacker = players.firstWhere((p) => p.color == attackerColor);
    final attackerStackCount = attacker.tokens
        .where((t) => t.zone == TokenZone.mainTrack && t.mainTrackIndex == tile)
        .length;

    for (int i = 0; i < players.length; i++) {
      final opp = players[i];
      if (areTeammates(attackerColor, opp.color, config)) continue;
      final oppOnTile = opp.tokens
          .where((t) => t.zone == TokenZone.mainTrack && t.mainTrackIndex == tile)
          .toList();
      if (oppOnTile.isEmpty) continue;

      if (oppOnTile.length == 3 &&
          attackerStackCount >= 2 &&
          config.tiggiRule == TiggiVsJotaRule.delayedRemainingKill) {
        continue;
      }

      final tokens = List<TokenState>.from(opp.tokens);
      bool changed = false;
      for (int t = 0; t < tokens.length; t++) {
        if (tokens[t].zone == TokenZone.mainTrack && tokens[t].mainTrackIndex == tile) {
          if (tokens[t].isKuti && !config.kutiVulnerable) continue;
          capturedIds.add(tokens[t].id);
          tokens[t] = tokens[t].copyWith(
            zone: TokenZone.yard,
            mainTrackIndex: -1,
            progressSteps: -1,
            homeColumnColor: null,
            homeColumnDepth: 0,
            isKuti: false,
          );
          changed = true;
        }
      }
      if (changed) {
        players[i] = opp.copyWith(tokens: tokens);
      }
    }
  }
}
