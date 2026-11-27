import 'package:flutter/material.dart';
import 'package:ludo_rules/ludo_rules.dart';
import '../core/theme/app_theme.dart';

class TwinDice3DWidget extends StatelessWidget {
  final TwinDiceRoll? activeDice;
  final int expectedDiceCount;
  final bool canRoll;
  final VoidCallback onRollTap;

  const TwinDice3DWidget({
    super.key,
    required this.activeDice,
    required this.expectedDiceCount,
    required this.canRoll,
    required this.onRollTap,
  });

  @override
  Widget build(BuildContext context) {
    final values = activeDice?.values ?? List<int>.filled(expectedDiceCount, 6);
    final used = activeDice?.used ?? List<bool>.filled(expectedDiceCount, false);

    return GestureDetector(
      onTap: canRoll ? onRollTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: canRoll
                ? [AppColors.royalGold, const Color(0xFFD97706)]
                : [const Color(0xFF1E2942), const Color(0xFF141B2D)],
          ),
          boxShadow: canRoll
              ? [BoxShadow(color: AppColors.royalGold.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < values.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              _DieCubeFace(
                value: values[i],
                isUsed: activeDice != null && used[i],
                isSix: values[i] == 6,
              ),
            ],
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  canRoll ? 'TAP TO ROLL' : (activeDice != null ? 'PICK MOVE' : 'WAIT TURN'),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: canRoll ? AppColors.darkBg : Colors.white,
                  ),
                ),
                Text(
                  expectedDiceCount == 1 ? '1-DIE LOCK (1 GOTI LEFT)' : 'TWIN DICE (6+X KUTI)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    color: canRoll ? AppColors.darkBg.withValues(alpha: 0.8) : AppColors.activeCyan,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DieCubeFace extends StatelessWidget {
  final int value;
  final bool isUsed;
  final bool isSix;

  const _DieCubeFace({
    required this.value,
    required this.isUsed,
    required this.isSix,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isUsed ? 0.38 : 1.0,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isSix ? AppColors.kutiCrimson : Colors.black26,
            width: isSix ? 2.5 : 1.5,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Center(
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isSix ? AppColors.kutiCrimson : AppColors.darkBg,
            ),
          ),
        ),
      ),
    );
  }
}
