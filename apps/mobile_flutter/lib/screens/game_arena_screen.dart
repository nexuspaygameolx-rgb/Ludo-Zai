import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ludo_rules/ludo_rules.dart';
import '../core/theme/app_theme.dart';
import '../services/gemini_agent_service.dart';
import '../services/offline_p2p_service.dart';
import '../widgets/board_3d_widget.dart';

class GameArenaScreen extends StatefulWidget {
  final bool isOnlineMode;
  final LudoRulesConfig rulesConfig;
  final List<PlayerState> initialPlayers;
  final GeminiAgentService geminiService;
  final OfflineP2PService p2pService;

  const GameArenaScreen({
    super.key,
    required this.isOnlineMode,
    required this.rulesConfig,
    required this.initialPlayers,
    required this.geminiService,
    required this.p2pService,
  });

  @override
  State<GameArenaScreen> createState() => _GameArenaScreenState();
}

class _GameArenaScreenState extends State<GameArenaScreen> {
  late List<PlayerState> _players;
  int _activeSeat = 0;
  TwinDiceRoll? _dice;
  List<LegalMove> _legalMoves = [];
  String _statusBanner = 'Roll the Twin Dice!';
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
      await Future.delayed(const Duration(milliseconds: 900));
      _advanceTurn(bonusTurn: false, rolledSix: false);
      return;
    }

    // If active seat is Gemini AI (Online Mode), let Gemini choose & speak its move!
    if (_activePlayer.isGeminiAi && widget.isOnlineMode) {
      final decision = await widget.geminiService.chooseAutonomousMove(
        geminiPlayer: _activePlayer,
        allPlayers: _players,
        dice: roll,
        legalMoves: moves,
        config: widget.rulesConfig,
      );
      if (decision.moveIndex >= 0 && mounted) {
        setState(() => _statusBanner = '${_activePlayer.name}: ${decision.spokenReaction}');
        await Future.delayed(const Duration(milliseconds: 700));
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
      _showWinnerDialog(res.winnerColor!);
      return;
    }

    if (nextDice.allUsed || remainingMoves.isEmpty) {
      final rolledSix = nextDice.values.contains(6);
      setState(() => _dice = null);
      _advanceTurn(bonusTurn: res.grantBonusTurn, rolledSix: rolledSix);
    } else if (_activePlayer.isGeminiAi && widget.isOnlineMode) {
      // Second die move for Gemini AI
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
    if (_activePlayer.isGeminiAi && widget.isOnlineMode) {
      Future.delayed(const Duration(milliseconds: 650), _rollDice);
    }
  }

  void _showWinnerDialog(PlayerColor winner) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Match Complete!'),
        content: Text('${winner.name.toUpperCase()} won the Desi Kuti Ludo match!'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isOnlineMode ? 'Online 3D Kuti Arena' : 'Offline P2P Arena'),
        actions: [
          IconButton(
            icon: Icon(widget.p2pService.micEnabled ? Icons.mic : Icons.mic_off, color: AppColors.activeCyan),
            onPressed: () {
              setState(() => widget.p2pService.micEnabled = !widget.p2pService.micEnabled);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Live Status & Ulti Kuti Banner
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

          // 3D Isometric Board
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Board3DWidget(
                  players: _players,
                  localPerspectiveColor: PlayerColor.red,
                  highlightedMoves: _legalMoves,
                  onSelectMove: _executeMove,
                ),
              ),
            ),
          ),

          // Legal Move Quick Selector Chips (for 6+X Ulti Kuti & split twin dice)
          if (_legalMoves.isNotEmpty)
            SizedBox(
              height: 46,
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

          // Twin 3D Dice Tray + Live Voice/Text Chat Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.casino),
                        label: Text(
                          _dice == null
                              ? 'ROLL DICE (${DiceHelper.diceCountForPlayer(_activePlayer, widget.rulesConfig)}D)'
                              : 'DICE: ${_dice!.remainingValues.join(" + ")}',
                        ),
                        onPressed: _activePlayer.isGeminiAi ? null : _rollDice,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatCtrl,
                        decoration: InputDecoration(
                          hintText: widget.isOnlineMode
                              ? 'Chat with players or ${widget.geminiService.companionDisplayName} AI...'
                              : 'Offline local chat (no internet)...',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        final msg = _chatCtrl.text.trim();
                        if (msg.isEmpty) return;
                        _chatCtrl.clear();
                        if (widget.isOnlineMode && widget.geminiService.hasApiKey) {
                          final reply = await widget.geminiService.sendConversationMessage(
                            userMessage: msg,
                            isOnlineMode: true,
                            boardContextSummary: _statusBanner,
                          );
                          if (mounted) setState(() => _statusBanner = '${widget.geminiService.companionDisplayName}: $reply');
                        } else {
                          widget.p2pService.sendChatMessage('You', msg);
                        }
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
}
