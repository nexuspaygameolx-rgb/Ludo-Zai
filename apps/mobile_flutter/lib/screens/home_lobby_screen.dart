import 'package:flutter/material.dart';
import 'package:ludo_rules/ludo_rules.dart';
import '../core/config/remote_config_service.dart';
import '../core/theme/app_theme.dart';
import '../services/cashmaal_store_service.dart';
import '../services/gemini_agent_service.dart';
import '../services/local_progress_service.dart';
import '../services/offline_p2p_service.dart';
import 'custom_rules_studio_screen.dart';
import 'game_arena_screen.dart';
import 'gemini_settings_screen.dart';
import 'offline_p2p_lobby_screen.dart';
import 'store_and_dices_screen.dart';

class HomeLobbyScreen extends StatefulWidget {
  final RemoteConfigService remoteConfig;
  final LocalProgressService localProgress;
  final OfflineP2PService p2pService;
  final GeminiAgentService geminiService;

  const HomeLobbyScreen({
    super.key,
    required this.remoteConfig,
    required this.localProgress,
    required this.p2pService,
    required this.geminiService,
  });

  @override
  State<HomeLobbyScreen> createState() => _HomeLobbyScreenState();
}

class _HomeLobbyScreenState extends State<HomeLobbyScreen> {
  final CashMaalStoreService _store = CashMaalStoreService();
  Map<String, dynamic> _stats = {
    'isGuest': true,
    'coins': 2500,
    'gems': 25,
    'trophies': 0,
    'level': 1,
    'league': 'Guest (Device Save)',
  };
  LudoRulesConfig _activeRules = LudoRulesConfig.punjabKutiSpecial();

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final s = await _store.fetchWalletAndProfile(widget.localProgress);
    if (mounted) setState(() => _stats = s);
  }

  void _launchMatch({required bool isOnlineMode, required bool includeGeminiPlayer, bool team2v2 = false}) {
    final cfg = _activeRules.copyWith(teamMode2v2: team2v2);
    final players = <PlayerState>[
      PlayerState(
        playerId: 'local_user',
        name: _stats['isGuest'] == true ? 'Guest Player' : (_stats['email'] as String? ?? 'You'),
        color: PlayerColor.red,
        tokens: List.generate(4, (i) => TokenState(id: 'red_$i', owner: PlayerColor.red)),
      ),
    ];

    if (includeGeminiPlayer && isOnlineMode) {
      final aiColor = team2v2 ? PlayerColor.yellow : PlayerColor.green;
      players.add(PlayerState(
        playerId: 'gemini_ai',
        name: '${widget.geminiService.companionDisplayName} (AI)',
        color: aiColor,
        isBot: true,
        isGeminiAi: true,
        tokens: List.generate(4, (i) => TokenState(id: '${aiColor.name}_$i', owner: aiColor)),
      ));
    } else {
      players.add(PlayerState(
        playerId: 'bot_1',
        name: 'Desi Ustaad Bot',
        color: PlayerColor.green,
        isBot: true,
        tokens: List.generate(4, (i) => TokenState(id: 'green_$i', owner: PlayerColor.green)),
      ));
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameArenaScreen(
          isOnlineMode: isOnlineMode,
          rulesConfig: cfg,
          initialPlayers: players,
          geminiService: widget.geminiService,
          p2pService: widget.p2pService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = _stats['isGuest'] == true;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Top Royal Currency & Level Bar
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.royalGold,
                  child: Text(
                    'L${_stats['level']}',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.darkBg),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _currencyChip(Icons.monetization_on, '${_stats['coins']}', AppColors.royalGold),
                      _currencyChip(Icons.diamond, '${_stats['gems']}', AppColors.activeCyan),
                      _currencyChip(Icons.emoji_events, '${_stats['trophies']}', AppColors.tokenGreen),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.auto_awesome, color: AppColors.activeCyan),
                  tooltip: 'Gemini AI Companion & Player',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GeminiSettingsScreen(geminiService: widget.geminiService),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Optional Gmail Registration Banner (Guest progress saved locally on device)
            if (isGuest)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.royalGold.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_android, color: AppColors.royalGold, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Guest Mode (Device Save): Offline & Online khelein; Buy/Sell ke liye Gmail link karein.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.localProgress.signInWithGmailAndSync(),
                      child: const Text('GMAIL SYNC', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),

            // Hero Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F2A48), Color(0xFF3A1628)],
                ),
                border: Border.all(color: AppColors.royalGold.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: AppColors.kutiCrimson, size: 28),
                      const SizedBox(width: 8),
                      const Text(
                        '3D DESI KUTI LUDO',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.kutiCrimson,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('6+X KUTI ON', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '100 Rs = 1,000 Coins | 100 Rs = 100 Gems | 1 Gem = 10 Coins | CashMaal Direct Auto-Withdraw!',
                    style: TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 4 Main Mode Cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                _modeCard(
                  title: 'Kuti Online Arena',
                  subtitle: 'Guest ya Gmail Dono Chalein',
                  icon: Icons.public,
                  accent: AppColors.kutiCrimson,
                  onTap: () => _launchMatch(isOnlineMode: true, includeGeminiPlayer: false),
                ),
                _modeCard(
                  title: 'Play With Gemini AI',
                  subtitle: 'AI Plays & Talks Live',
                  icon: Icons.record_voice_over,
                  accent: AppColors.activeCyan,
                  onTap: () => _launchMatch(isOnlineMode: true, includeGeminiPlayer: true),
                ),
                _modeCard(
                  title: 'Apne Mobile (Offline)',
                  subtitle: 'Nearby / Hotspot + Mic',
                  icon: Icons.wifi_tethering,
                  accent: AppColors.tokenGreen,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OfflineP2PLobbyScreen(
                        p2pService: widget.p2pService,
                        rulesConfig: _activeRules,
                      ),
                    ),
                  ),
                ),
                _modeCard(
                  title: '2v2 Jodi Match',
                  subtitle: 'Partner + Gemini Team',
                  icon: Icons.groups,
                  accent: AppColors.royalGold,
                  onTap: () => _launchMatch(isOnlineMode: true, includeGeminiPlayer: true, team2v2: true),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.tune),
                    label: const Text('Rule Switches'),
                    onPressed: () async {
                      final updated = await Navigator.push<LudoRulesConfig>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomRulesStudioScreen(initialConfig: _activeRules),
                        ),
                      );
                      if (updated != null) setState(() => _activeRules = updated);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.tokenGreen, foregroundColor: Colors.white),
                    icon: const Icon(Icons.storefront),
                    label: const Text('CashMaal & 3D'),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StoreAndDicesScreen(
                            remoteConfig: widget.remoteConfig,
                            localProgress: widget.localProgress,
                          ),
                        ),
                      );
                      _loadStats();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _currencyChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _modeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(
              backgroundColor: accent.withValues(alpha: 0.18),
              child: Icon(icon, color: accent),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.72))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
