import 'package:ludo_rules/ludo_rules.dart';
import 'package:test/test.dart';

void main() {
  group('Desi Kuti LudoRuleEngine', () {
    test('Auto switches from 2 dice to 1 die when 3 tokens are finished (1 remaining)', () {
      const config = LudoRulesConfig(kutiMode: true, autoSingleDiceOnLastToken: true);
      const pTwoLeft = PlayerState(
        playerId: 'p1',
        name: 'Ali',
        color: PlayerColor.red,
        tokens: [
          TokenState(id: 'red_0', owner: PlayerColor.red, zone: TokenZone.finished),
          TokenState(id: 'red_1', owner: PlayerColor.red, zone: TokenZone.finished),
          TokenState(id: 'red_2', owner: PlayerColor.red, zone: TokenZone.mainTrack, mainTrackIndex: 5, progressSteps: 5),
          TokenState(id: 'red_3', owner: PlayerColor.red, zone: TokenZone.yard),
        ],
      );
      expect(DiceHelper.diceCountForPlayer(pTwoLeft, config), 2);

      const pOneLeft = PlayerState(
        playerId: 'p1',
        name: 'Ali',
        color: PlayerColor.red,
        tokens: [
          TokenState(id: 'red_0', owner: PlayerColor.red, zone: TokenZone.finished),
          TokenState(id: 'red_1', owner: PlayerColor.red, zone: TokenZone.finished),
          TokenState(id: 'red_2', owner: PlayerColor.red, zone: TokenZone.finished),
          TokenState(id: 'red_3', owner: PlayerColor.red, zone: TokenZone.mainTrack, mainTrackIndex: 10, progressSteps: 10),
        ],
      );
      expect(DiceHelper.diceCountForPlayer(pOneLeft, config), 1);
    });

    test('Ghar Wali Ulti Kuti (6 + X) captures opponent inside home column and flips token to reverse Kuti', () {
      final config = LudoRulesConfig.punjabKutiSpecial();
      const attacker = PlayerState(
        playerId: 'p1',
        name: 'Hamza',
        color: PlayerColor.red,
        tokens: [
          TokenState(id: 'red_0', owner: PlayerColor.red, zone: TokenZone.finished),
          TokenState(id: 'red_1', owner: PlayerColor.red, zone: TokenZone.mainTrack, mainTrackIndex: 4, progressSteps: 4),
          TokenState(id: 'red_2', owner: PlayerColor.red, zone: TokenZone.yard),
          TokenState(id: 'red_3', owner: PlayerColor.red, zone: TokenZone.yard),
        ],
      );
      // Opponent green token is at homeColumnDepth 3 -> distanceToFinish = 6 - 3 = 3
      const defender = PlayerState(
        playerId: 'p2',
        name: 'Bilal',
        color: PlayerColor.green,
        tokens: [
          TokenState(
            id: 'green_0',
            owner: PlayerColor.green,
            zone: TokenZone.homeColumn,
            homeColumnColor: PlayerColor.green,
            homeColumnDepth: 3,
          ),
          TokenState(id: 'green_1', owner: PlayerColor.green, zone: TokenZone.yard),
          TokenState(id: 'green_2', owner: PlayerColor.green, zone: TokenZone.yard),
          TokenState(id: 'green_3', owner: PlayerColor.green, zone: TokenZone.yard),
        ],
      );

      const dice = TwinDiceRoll(values: [6, 3], used: [false, false]);
      final moves = LudoRuleEngine.getLegalMoves(
        activePlayer: attacker,
        allPlayers: [attacker, defender],
        dice: dice,
        config: config,
      );

      final kutiMove = moves.firstWhere((m) => m.moveType == MoveType.gharWaliUltiKuti && m.tokenId == 'red_1');
      final res = LudoRuleEngine.executeMove(
        activePlayer: attacker,
        allPlayers: [attacker, defender],
        move: kutiMove,
        config: config,
      );

      expect(res.triggeredUltiKuti, isTrue);
      expect(res.capturedTokenIds, contains('green_0'));
      final updatedRed1 = res.updatedPlayers[0].tokens.firstWhere((t) => t.id == 'red_1');
      expect(updatedRed1.isKuti, isTrue);
      expect(res.grantBonusTurn, isTrue);
    });

    test('Reverse Kuti sweeps safe-zone tokens when moving anti-clockwise', () {
      final config = LudoRulesConfig.punjabKutiSpecial();
      const attacker = PlayerState(
        playerId: 'p1',
        name: 'Hamza',
        color: PlayerColor.red,
        tokens: [
          TokenState(id: 'red_0', owner: PlayerColor.red, zone: TokenZone.finished),
          TokenState(id: 'red_1', owner: PlayerColor.red, zone: TokenZone.mainTrack, mainTrackIndex: 10, progressSteps: 10, isKuti: true),
          TokenState(id: 'red_2', owner: PlayerColor.red, zone: TokenZone.yard),
          TokenState(id: 'red_3', owner: PlayerColor.red, zone: TokenZone.yard),
        ],
      );
      // Opponent token sitting on Star safe tile #8
      const defender = PlayerState(
        playerId: 'p2',
        name: 'Bilal',
        color: PlayerColor.green,
        tokens: [
          TokenState(id: 'green_0', owner: PlayerColor.green, zone: TokenZone.mainTrack, mainTrackIndex: 8, progressSteps: 47),
          TokenState(id: 'green_1', owner: PlayerColor.green, zone: TokenZone.yard),
          TokenState(id: 'green_2', owner: PlayerColor.green, zone: TokenZone.yard),
          TokenState(id: 'green_3', owner: PlayerColor.green, zone: TokenZone.yard),
        ],
      );

      const dice = TwinDiceRoll(values: [4], used: [false]);
      final moves = LudoRuleEngine.getLegalMoves(
        activePlayer: attacker,
        allPlayers: [attacker, defender],
        dice: dice,
        config: config,
      );
      final revMove = moves.firstWhere((m) => m.moveType == MoveType.reverseKutiAdvance);
      final res = LudoRuleEngine.executeMove(
        activePlayer: attacker,
        allPlayers: [attacker, defender],
        move: revMove,
        config: config,
      );

      expect(res.capturedTokenIds, contains('green_0'));
      final updatedRed1 = res.updatedPlayers[0].tokens.firstWhere((t) => t.id == 'red_1');
      expect(updatedRed1.mainTrackIndex, 6); // 10 - 4 = 6 anti-clockwise
    });
  });
}
