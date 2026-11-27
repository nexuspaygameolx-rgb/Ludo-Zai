import 'dart:math';
import 'config.dart';
import 'models.dart';

class TwinDiceRoll {
  final List<int> values; // length 1 or 2
  final List<bool> used;

  const TwinDiceRoll({
    required this.values,
    required this.used,
  });

  bool get allUsed => used.every((u) => u);
  bool get isTwin => values.length == 2;
  bool get isDoubleSix => values.length == 2 && values[0] == 6 && values[1] == 6;
  bool get hasSix => values.contains(6);

  List<int> get remainingValues {
    final res = <int>[];
    for (int i = 0; i < values.length; i++) {
      if (!used[i]) res.add(values[i]);
    }
    return res;
  }

  TwinDiceRoll markUsed(List<int> indices) {
    final nextUsed = List<bool>.from(used);
    for (final idx in indices) {
      if (idx >= 0 && idx < nextUsed.length) {
        nextUsed[idx] = true;
      }
    }
    return TwinDiceRoll(values: values, used: nextUsed);
  }
}

class DiceHelper {
  /// Determines whether the current player rolls 1 or 2 dice based on Kuti Mode
  /// and the "1 Goti Remaining = 1 Dice" rule.
  static int diceCountForPlayer(PlayerState player, LudoRulesConfig config) {
    if (!config.kutiMode) return 1;
    if (config.autoSingleDiceOnLastToken && player.remainingTokensCount <= 1) {
      return 1;
    }
    return 2;
  }

  static TwinDiceRoll roll(PlayerState player, LudoRulesConfig config, [Random? rng]) {
    final random = rng ?? Random.secure();
    final count = diceCountForPlayer(player, config);
    final vals = List<int>.generate(count, (_) => random.nextInt(6) + 1);
    return TwinDiceRoll(
      values: vals,
      used: List<bool>.filled(count, false),
    );
  }
}
