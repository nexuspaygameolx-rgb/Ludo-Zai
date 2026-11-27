import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ludo_rules/ludo_rules.dart';
import '../core/theme/app_theme.dart';
import '../services/gemini_agent_service.dart';
import '../services/local_progress_service.dart';
import '../services/offline_p2p_service.dart';
import '../widgets/board_3d_widget.dart';
import '../widgets/twin_dice_3d_widget.dart';

class GameArenaScreen extends StatefulWidget {
  final bool isOnlineMode;
  final bool isOfflineP2P;
  final LudoRulesConfig rulesConfig;
  final List<PlayerState> initialPlayers;
  final GeminiAgentService geminiService;
  final OfflineP2PService p2pService;
  final LocalProgressService localProgress;

  const GameArenaScreen({
    super.key,
    required this.isOnlineMode,
    this.isOfflineP2P = false,
    required this.rulesConfig,
    required this.initialPlayers,
    required this.geminiService,
    required this.p2pService,
    required this.localProgress,
  });

  @override
  State<GameArenaScreen> createState() => _GameArenaScreenState();
}

class _GameArenaScreenState extends State<GameArenaScreen> {
  late List<PlayerState> _players;
  int _activeSeat = 0;
  TwinDiceRoll? _dice;
  List<LegalMove> _legalMoves = [];
  String _statusBanner = 'Tap Twin Dice to Roll!';
  final TextEditingController _chatCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _players = widget.initialPlayers;
  }

  PlayerState get _activePlayer => _players[_activeSeat];

  Future<void> _rollDice() async {
    if (_dice != null && !_dice!.allUsed) return;
    HapticFeedback.mediumImpact();

    if (widget.isOfflineP2P) {
      widget.p2pService.hostRollDice();
      return;
    }

    final roll = DiceHelper.roll(_activePlayer, widget.rulesConfig);
    final moves = LudoRuleEngine.getLegalMoves(
      activePlayer: _activePlayer,
      allPlayers: _players,
      dice: roll,
      config: widget.rulesConfig,
    );

    setState(() {
      _dice = roll;
      _legalMoves = moves;
      _statusBanner = '${_activePlayer.name} rolled ${roll.values.join(" & ")}';
    });

    if (moves.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 850));
      _advanceTurn(bonusTurn: false, rolledSix: false);
      return;
    }

    // Gemini AI plays ONLY when online AND Play-with-Buddy switch is ON
    if (_activePlayer.isGeminiAi && widget.isOnlineMode && widget.geminiService.canPlayInOnlineMatch) {
      final decision = await widget.geminiService.chooseAutonomousMove(
        geminiPlayer: _activePlayer,
        allPlayers: _players,
        dice: roll,
        legalMoves: moves,
        config: widget.rulesConfig,
      );
      if (decision.moveIndex >= 0 && mounted) {
        setState(() => _statusBanner = '${_activePlayer.name}: ${decision.spokenReaction}');
        await Future.delayed(const Duration(milliseconds: 650));
        await _executeMove(moves[decision.moveIndex]);
      }
    }
  }

  Future<void> _executeMove(LegalMove move) async {
    final res = LudoRuleEngine.executeMove(
      activePlayer: _activePlayer,
      allPlayers: _players,
      move: move,
      config: widget.rulesConfig,
    );

    if (res.triggeredUltiKuti) {
      HapticFeedback.heavyImpact();
    }

    final nextDice = _dice!.markUsed(move.diceUsedIndices);
    final remainingMoves = nextDice.allUsed
        ? <LegalMove>[]
        : LudoRuleEngine.getLegalMoves(
            activePlayer: res.updatedPlayers[_activeSeat],
            allPlayers: res.updatedPlayers,
            dice: nextDice,
            config: widget.rulesConfig,
          );

    setState(() {
      _players = res.updatedPlayers;
      _dice = nextDice.allUsed ? null : nextDice;
      _legalMoves = remainingMoves;
      _statusBanner = res.eventSummary;
    });

    if (res.winnerColor != null) {
      final me = _players.first;
      final won = res.winnerColor == me.color;
      await widget.localProgress.recordGuestMatchResult(
        won: won,
        coinsDelta: won ? 1000 : 0,
        gemsDelta: won ? 5 : 0,
        trophiesDelta: won ? 30 : 0,
        xpGain: won ? 150 : 50,
        kutiCount: me.kutiCount,
        modeName: widget.isOnlineMode ? 'Online Kuti Arena' : 'Offline Desi Match',
      );
      _showWinnerDialog(res.winnerColor!);
      return;
    }

    if (nextDice.allUsed || remainingMoves.isEmpty) {
      final rolledSix = nextDice.values.contains(6);
      setState(() => _dice = null);
      _advanceTurn(bonusTurn: res.grantBonusTurn, rolledSix: rolledSix);
    } else if (_activePlayer.isGeminiAi && widget.isOnlineMode && widget.geminiService.canPlayInOnlineMatch) {
      final decision2 = await widget.geminiService.chooseAutonomousMove(
        geminiPlayer: _activePlayer,
        allPlayers: _players,
        dice: nextDice,
        legalMoves: remainingMoves,
        config: widget.rulesConfig,
      );
      if (decision2.moveIndex >= 0 && mounted) {
        await _executeMove(remainingMoves[decision2.moveIndex]);
      }
    }
  }

  void _advanceTurn({required bool bonusTurn, required bool rolledSix}) {
    if (!bonusTurn && !rolledSix) {
      setState(() {
        _activeSeat = (_activeSeat + 1) % _players.length;
        _legalMoves = [];
      });
    }
    if (_activePlayer.isGeminiAi && widget.isOnlineMode && widget.geminiService.canPlayInOnlineMatch) {
      Future.delayed(const Duration(milliseconds: 600), _rollDice);
    }
  }

  void _showWinnerDialog(PlayerColor winner) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Match Complete!'),
        content: Text('${winner.name.toUpperCase()} ne Desi Kuti Ludo jeet li! Progress save ho gayi hai.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Back to Lobby'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendGupshup(String text) async {
    final msg = text.trim();
    if (msg.isEmpty) return;
    if (widget.isOnlineMode && widget.geminiService.hasApiKey) {
      final reply = await widget.geminiService.sendConversationMessage(
        userMessage: msg,
        isOnlineMode: true,
        boardContextSummary: _statusBanner,
      );
      if (mounted) {
        setState(() => _statusBanner = '${widget.geminiService.companionDisplayName}: $reply');
      }
    } else {
      widget.p2pService.sendChatMessage('You', msg);
      setState(() => _statusBanner = 'You: $msg');
    }
  }

  @override
  Widget build(BuildContext context) {
    final perspective = widget.isOfflineP2P ? widget.p2pService.localPlayerColor : PlayerColor.red;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isOnlineMode ? 'Online 3D Kuti Arena' : 'Offline 3D P2P Arena'),
        actions: [
          IconButton(
            icon: Icon(widget.p2pService.micEnabled ? Icons.mic : Icons.mic_off, color: AppColors.activeCyan),
            tooltip: 'Toggle Live Voice Mic',
            onPressed: () {
              setState(() => widget.p2pService.micEnabled = !widget.p2pService.micEnabled);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.royalGold.withValues(alpha: 0.5)),
            ),
            child: Text(
              _statusBanner,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Board3DWidget(
                  players: _players,
                  localPerspectiveColor: perspective,
                  highlightedMoves: _legalMoves,
                  onSelectMove: _executeMove,
                ),
              ),
            ),
          ),

          if (_legalMoves.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _legalMoves.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final m = _legalMoves[idx];
                  final isKuti = m.moveType == MoveType.gharWaliUltiKuti;
                  return ActionChip(
                    backgroundColor: isKuti ? AppColors.kutiCrimson : AppColors.darkCard,
                    label: Text(
                      m.description,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => _executeMove(m),
                  );
                },
              ),
            ),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                TwinDice3DWidget(
                  activeDice: _dice,
                  expectedDiceCount: DiceHelper.diceCountForPlayer(_activePlayer, widget.rulesConfig),
                  canRoll: !_activePlayer.isGeminiAi && (_dice == null || _dice!.allUsed),
                  onRollTap: _rollDice,
                ),
                const SizedBox(height: 8),
                if (widget.isOnlineMode && widget.geminiService.hasApiKey)
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _quickBanterChip('Kuti marun ya bachun?'),
                        const SizedBox(width: 6),
                        _quickBanterChip('Koi spicy gupshup sunao!'),
                        const SizedBox(width: 6),
                        _quickBanterChip('Meri agli chaal batao'),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatCtrl,
                        decoration: InputDecoration(
                          hintText: widget.isOnlineMode
                              ? 'Gupshup with ${widget.geminiService.companionDisplayName}...'
                              : 'Offline local chat (no internet)...',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.send),
                      onPressed: () {
                        final txt = _chatCtrl.text;
                        _chatCtrl.clear();
                        _sendGupshup(txt);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickBanterChip(String prompt) {
    return ActionChip(
      label: Text(prompt, style: const TextStyle(fontSize: 11)),
      onPressed: () => _sendGupshup(prompt),
    );
  }
}
