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
import 'records_and_leagues_screen.dart';
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
  int _tabIndex = 0;
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

  void _launchMatch({required bool isOnlineMode, bool team2v2 = false}) {
    final cfg = _activeRules.copyWith(teamMode2v2: team2v2);
    final useGeminiBuddy = isOnlineMode && widget.geminiService.canPlayInOnlineMatch;

    final players = <PlayerState>[
      PlayerState(
        playerId: 'local_user',
        name: _stats['isGuest'] == true ? 'Guest Player' : (_stats['email'] as String? ?? 'You'),
        color: PlayerColor.red,
        tokens: List.generate(4, (i) => TokenState(id: 'red_$i', owner: PlayerColor.red)),
      ),
    ];

    if (useGeminiBuddy) {
      final aiColor = team2v2 ? PlayerColor.yellow : PlayerColor.green;
      players.add(PlayerState(
        playerId: 'gemini_ai',
        name: '${widget.geminiService.companionDisplayName} (Buddy)',
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
          localProgress: widget.localProgress,
        ),
      ),
    ).then((_) => _loadStats());
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildLobbyTab(),
      StoreAndDicesScreen(remoteConfig: widget.remoteConfig, localProgress: widget.localProgress),
      RecordsAndLeaguesScreen(localProgress: widget.localProgress),
      GeminiSettingsScreen(geminiService: widget.geminiService),
    ];

    return Scaffold(
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) {
          setState(() => _tabIndex = i);
          if (i == 0) _loadStats();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.castle_rounded), label: 'Lobby'),
          NavigationDestination(icon: Icon(Icons.storefront_rounded), label: 'Store & 3D'),
          NavigationDestination(icon: Icon(Icons.leaderboard_rounded), label: 'Records'),
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'AI Buddy'),
        ],
      ),
    );
  }

  Widget _buildLobbyTab() {
    final isGuest = _stats['isGuest'] == true;
    return AnimatedBuilder(
      animation: widget.geminiService,
      builder: (context, _) {
        final buddyReady = widget.geminiService.canPlayInOnlineMatch;
        return SafeArea(
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
                ],
              ),
              const SizedBox(height: 12),

              // Optional Gmail Sync Banner
              if (isGuest)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.royalGold.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_android, color: AppColors.royalGold, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Guest Mode (Device Save): Offline & Online khelein; Buy/Sell ke liye Gmail link karein.',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                      TextButton(
                        onPressed: () => widget.localProgress.signInWithGmailAndSync(),
                        child: const Text('GMAIL', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ),

              // Hero 3D Kuti Card + Explicit Play-with-Buddy Switch
              Container(
                padding: const EdgeInsets.all(18),
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
                        const Icon(Icons.local_fire_department, color: AppColors.kutiCrimson, size: 26),
                        const SizedBox(width: 8),
                        const Text(
                          '3D DESI KUTI LUDO',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.kutiCrimson,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('6+X KUTI', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        'Play with Buddy (${widget.geminiService.companionDisplayName})',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      subtitle: Text(
                        !widget.geminiService.hasApiKey
                            ? 'AI Buddy tab mein Gemini Key lagayein'
                            : (buddyReady
                                ? 'ON — ${widget.geminiService.companionDisplayName} online match mein khelegi & gupshup karegi'
                                : 'OFF — Normal match chalega'),
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      value: widget.geminiService.playWithBuddyEnabled,
                      activeThumbColor: AppColors.activeCyan,
                      onChanged: (v) {
                        if (v && !widget.geminiService.hasApiKey) {
                          setState(() => _tabIndex = 3);
                          return;
                        }
                        widget.geminiService.setPlayWithBuddySwitch(v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

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
                    subtitle: buddyReady ? 'With ${widget.geminiService.companionDisplayName}' : '1v1 / 4P Online',
                    icon: Icons.public,
                    accent: AppColors.kutiCrimson,
                    onTap: () => _launchMatch(isOnlineMode: true),
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
                          geminiService: widget.geminiService,
                          localProgress: widget.localProgress,
                        ),
                      ),
                    ),
                  ),
                  _modeCard(
                    title: '2v2 Jodi Match',
                    subtitle: buddyReady ? 'Partner: ${widget.geminiService.companionDisplayName}' : 'Team-Up Mode',
                    icon: Icons.groups,
                    accent: AppColors.royalGold,
                    onTap: () => _launchMatch(isOnlineMode: true, team2v2: true),
                  ),
                  _modeCard(
                    title: 'Rule Switches',
                    subtitle: 'Kuti, Tiggi & Custom Rules',
                    icon: Icons.tune,
                    accent: AppColors.activeCyan,
                    onTap: () async {
                      final updated = await Navigator.push<LudoRulesConfig>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomRulesStudioScreen(initialConfig: _activeRules),
                        ),
                      );
                      if (updated != null) setState(() => _activeRules = updated);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
