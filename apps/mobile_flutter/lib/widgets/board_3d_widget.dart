import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ludo_rules/ludo_rules.dart';
import '../core/theme/app_theme.dart';

/// Tilted 3D Isometric Ludo Board with:
/// - Per-device camera rotation so each player sees their own color at bottom-left.
/// - Real drop shadows & 3D depth bevels.
/// - Burning Crown aura on tokens that became [isKuti] (moving anti-clockwise).
class Board3DWidget extends StatelessWidget {
  final List<PlayerState> players;
  final PlayerColor localPerspectiveColor;
  final List<LegalMove> highlightedMoves;
  final void Function(LegalMove move) onSelectMove;

  const Board3DWidget({
    super.key,
    required this.players,
    required this.localPerspectiveColor,
    required this.highlightedMoves,
    required this.onSelectMove,
  });

  double _rotationAngleForColor(PlayerColor c) {
    switch (c) {
      case PlayerColor.red:
        return 0;
      case PlayerColor.green:
        return -math.pi / 2;
      case PlayerColor.yellow:
        return math.pi;
      case PlayerColor.blue:
        return math.pi / 2;
    }
  }

  Color _colorFor(PlayerColor c) {
    switch (c) {
      case PlayerColor.red:
        return AppColors.tokenRed;
      case PlayerColor.green:
        return AppColors.tokenGreen;
      case PlayerColor.yellow:
        return AppColors.tokenYellow;
      case PlayerColor.blue:
        return AppColors.tokenBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0009)
          ..rotateX(-0.18)
          ..rotateZ(_rotationAngleForColor(localPerspectiveColor)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E2942), Color(0xFF0F1626)],
            ),
            border: Border.all(color: AppColors.royalGold, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 24,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 15),
            itemCount: 225,
            itemBuilder: (context, index) {
              final row = index ~/ 15;
              final col = index % 15;
              return _buildCell(row, col);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col) {
    // Yard corners
    if (row < 6 && col < 6) return _yardCell(AppColors.tokenGreen, row, col);
    if (row < 6 && col > 8) return _yardCell(AppColors.tokenYellow, row, col - 9);
    if (row > 8 && col < 6) return _yardCell(AppColors.tokenRed, row - 9, col);
    if (row > 8 && col > 8) return _yardCell(AppColors.tokenBlue, row - 9, col - 9);

    // Center Victory Triangle
    if (row >= 6 && row <= 8 && col >= 6 && col <= 8) {
      return Container(
        decoration: BoxDecoration(
          gradient: const SweepGradient(
            colors: [
              AppColors.tokenYellow,
              AppColors.tokenBlue,
              AppColors.tokenRed,
              AppColors.tokenGreen,
              AppColors.tokenYellow,
            ],
          ),
          border: Border.all(color: Colors.white24, width: 0.5),
        ),
        child: const Center(
          child: Icon(Icons.emoji_events, color: Colors.white, size: 14),
        ),
      );
    }

    // Home Columns & Track Tiles
    Color tileBg = const Color(0xFF232E47);
    bool isSafeStar = false;
    if (row == 7 && col >= 1 && col <= 5) tileBg = AppColors.tokenRed.withValues(alpha: 0.65);
    if (col == 7 && row >= 1 && row <= 5) tileBg = AppColors.tokenGreen.withValues(alpha: 0.65);
    if (row == 7 && col >= 9 && col <= 13) tileBg = AppColors.tokenYellow.withValues(alpha: 0.65);
    if (col == 7 && row >= 9 && row <= 13) tileBg = AppColors.tokenBlue.withValues(alpha: 0.65);

    if ((row == 6 && col == 1) ||
        (row == 1 && col == 8) ||
        (row == 8 && col == 13) ||
        (row == 13 && col == 6) ||
        (row == 2 && col == 6) ||
        (row == 6 && col == 12) ||
        (row == 12 && col == 8) ||
        (row == 8 && col == 2)) {
      isSafeStar = true;
    }

    return Container(
      margin: const EdgeInsets.all(0.7),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.white12, width: 0.5),
      ),
      child: isSafeStar
          ? const Center(child: Icon(Icons.star_rounded, size: 11, color: AppColors.royalGold))
          : null,
    );
  }

  Widget _yardCell(Color baseColor, int r, int c) {
    final isTokenSlot = (r == 1 || r == 4) && (c == 1 || c == 4);
    final ownerColor = baseColor == AppColors.tokenRed
        ? PlayerColor.red
        : baseColor == AppColors.tokenGreen
            ? PlayerColor.green
            : baseColor == AppColors.tokenYellow
                ? PlayerColor.yellow
                : PlayerColor.blue;

    final player = players.where((p) => p.color == ownerColor).firstOrNull;
    final slotIdx = (r == 1 ? 0 : 2) + (c == 1 ? 0 : 1);
    final token = (player != null && slotIdx < player.tokens.length) ? player.tokens[slotIdx] : null;
    final movable = token != null && token.isInYard
        ? highlightedMoves.where((m) => m.tokenId == token.id).firstOrNull
        : null;

    return Container(
      color: baseColor.withValues(alpha: 0.25),
      child: isTokenSlot
          ? Center(
              child: GestureDetector(
                onTap: movable != null ? () => onSelectMove(movable) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (token != null && token.isInYard) ? _colorFor(ownerColor) : Colors.black26,
                    border: Border.all(
                      color: movable != null ? AppColors.activeCyan : Colors.white70,
                      width: movable != null ? 2.5 : 1.2,
                    ),
                    boxShadow: movable != null
                        ? [const BoxShadow(color: AppColors.activeCyan, blurRadius: 8)]
                        : null,
                  ),
                  child: (token != null && token.isKuti)
                      ? const Icon(Icons.local_fire_department, size: 11, color: Colors.white)
                      : null,
                ),
              ),
            )
          : null,
    );
  }
}
