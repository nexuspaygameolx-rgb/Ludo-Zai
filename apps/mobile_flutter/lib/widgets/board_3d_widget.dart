import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ludo_rules/ludo_rules.dart';
import '../core/theme/app_theme.dart';

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

  /// Exact 52-tile clockwise path on a 15x15 grid (row, col), starting at Red start (index 0 = (13, 6)).
  static const List<(int, int)> mainTrackCoords = [
    // Red upward arm (0..4)
    (13, 6), (12, 6), (11, 6), (10, 6), (9, 6),
    // Green left arm going left (5..10)
    (8, 5), (8, 4), (8, 3), (8, 2), (8, 1), (8, 0),
    // Left turn to top row (11..12)
    (7, 0), (6, 0),
    // Green start (13) & top arm going right (13..17)
    (6, 1), (6, 2), (6, 3), (6, 4), (6, 5),
    // Top arm going up (18..23)
    (5, 6), (4, 6), (3, 6), (2, 6), (1, 6), (0, 6),
    // Top turn to right column (24..25)
    (0, 7), (0, 8),
    // Yellow start (26) & top-right arm going down (26..30)
    (1, 8), (2, 8), (3, 8), (4, 8), (5, 8),
    // Right arm going right (31..36)
    (6, 9), (6, 10), (6, 11), (6, 12), (6, 13), (6, 14),
    // Right turn to bottom row (37..38)
    (7, 14), (8, 14),
    // Blue start (39) & bottom-right arm going left (39..43)
    (8, 13), (8, 12), (8, 11), (8, 10), (8, 9),
    // Bottom arm going down (44..49)
    (9, 8), (10, 8), (11, 8), (12, 8), (13, 8), (14, 8),
    // Bottom turn to Red gate (50..51)
    (14, 7), (14, 6),
  ];

  static (int, int)? homeColumnCoord(PlayerColor color, int depth) {
    if (depth < 1 || depth > 5) return null;
    switch (color) {
      case PlayerColor.red:
        return (14 - depth, 7);
      case PlayerColor.green:
        return (7, depth);
      case PlayerColor.yellow:
        return (depth, 7);
      case PlayerColor.blue:
        return (7, 14 - depth);
    }
  }

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

  List<TokenState> _tokensAtCell(int row, int col) {
    final result = <TokenState>[];
    for (final p in players) {
      for (final t in p.tokens) {
        if (t.zone == TokenZone.mainTrack && t.mainTrackIndex >= 0 && t.mainTrackIndex < mainTrackCoords.length) {
          if (mainTrackCoords[t.mainTrackIndex] == (row, col)) {
            result.add(t);
          }
        } else if (t.zone == TokenZone.homeColumn && t.homeColumnColor != null) {
          final hc = homeColumnCoord(t.homeColumnColor!, t.homeColumnDepth);
          if (hc == (row, col)) {
            result.add(t);
          }
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0009)
          ..rotateX(-0.16)
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
          padding: const EdgeInsets.all(8),
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
    if (row < 6 && col < 6) return _yardCell(AppColors.tokenGreen, row, col);
    if (row < 6 && col > 8) return _yardCell(AppColors.tokenYellow, row, col - 9);
    if (row > 8 && col < 6) return _yardCell(AppColors.tokenRed, row - 9, col);
    if (row > 8 && col > 8) return _yardCell(AppColors.tokenBlue, row - 9, col - 9);

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
        child: const Center(child: Icon(Icons.emoji_events, color: Colors.white, size: 13)),
      );
    }

    Color tileBg = const Color(0xFF232E47);
    bool isSafeStar = false;
    if (col == 7 && row >= 9 && row <= 13) tileBg = AppColors.tokenRed.withValues(alpha: 0.65);
    if (row == 7 && col >= 1 && col <= 5) tileBg = AppColors.tokenGreen.withValues(alpha: 0.65);
    if (col == 7 && row >= 1 && row <= 5) tileBg = AppColors.tokenYellow.withValues(alpha: 0.65);
    if (row == 7 && col >= 9 && col <= 13) tileBg = AppColors.tokenBlue.withValues(alpha: 0.65);

    if ((row == 13 && col == 6) ||
        (row == 6 && col == 1) ||
        (row == 1 && col == 8) ||
        (row == 8 && col == 13) ||
        (row == 8 && col == 2) ||
        (row == 2 && col == 6) ||
        (row == 6 && col == 12) ||
        (row == 12 && col == 8)) {
      isSafeStar = true;
    }

    final cellTokens = _tokensAtCell(row, col);
    LegalMove? actionableMove;
    for (final t in cellTokens) {
      final m = highlightedMoves.where((hm) => hm.tokenId == t.id || hm.targetTokenId == t.id).firstOrNull;
      if (m != null) {
        actionableMove = m;
        break;
      }
    }

    return GestureDetector(
      onTap: actionableMove != null ? () => onSelectMove(actionableMove!) : null,
      child: Container(
        margin: const EdgeInsets.all(0.6),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: actionableMove != null ? AppColors.activeCyan : Colors.white12,
            width: actionableMove != null ? 1.6 : 0.5,
          ),
        ),
        child: cellTokens.isNotEmpty
            ? _buildTokenStack(cellTokens, actionableMove != null)
            : (isSafeStar
                ? const Center(child: Icon(Icons.star_rounded, size: 10, color: AppColors.royalGold))
                : null),
      ),
    );
  }

  Widget _buildTokenStack(List<TokenState> stack, bool isHighlighted) {
    final top = stack.last;
    final hasKuti = stack.any((t) => t.isKuti);
    return Center(
      child: Container(
        width: 17,
        height: 17,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _colorFor(top.owner),
          border: Border.all(
            color: hasKuti
                ? AppColors.royalGold
                : (isHighlighted ? AppColors.activeCyan : Colors.white),
            width: hasKuti || isHighlighted ? 2.0 : 1.1,
          ),
          boxShadow: [
            if (hasKuti) const BoxShadow(color: AppColors.kutiCrimson, blurRadius: 7),
            if (isHighlighted) const BoxShadow(color: AppColors.activeCyan, blurRadius: 7),
          ],
        ),
        child: Center(
          child: stack.length > 1
              ? Text(
                  '${stack.length}',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                )
              : (hasKuti
                  ? const Icon(Icons.local_fire_department, size: 10, color: Colors.white)
                  : null),
        ),
      ),
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
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (token != null && token.isInYard) ? _colorFor(ownerColor) : Colors.black26,
                    border: Border.all(
                      color: movable != null ? AppColors.activeCyan : Colors.white70,
                      width: movable != null ? 2.2 : 1.1,
                    ),
                    boxShadow: movable != null
                        ? [const BoxShadow(color: AppColors.activeCyan, blurRadius: 8)]
                        : null,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
