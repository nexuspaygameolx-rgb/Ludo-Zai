import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/local_progress_service.dart';

class RecordsAndLeaguesScreen extends StatelessWidget {
  final LocalProgressService localProgress;
  const RecordsAndLeaguesScreen({super.key, required this.localProgress});

  String _leagueForTrophies(int t) {
    if (t >= 5000) return 'Legend League';
    if (t >= 3000) return 'Diamond League';
    if (t >= 1500) return 'Gold League';
    if (t >= 500) return 'Silver League';
    return 'Bronze League';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: localProgress,
      builder: (context, _) {
        final xpInLevel = localProgress.xp % 250;
        return Scaffold(
          appBar: AppBar(title: const Text('Levels, Leagues & Game Records')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Level & League Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(colors: [Color(0xFF1F2A48), Color(0xFF141B2D)]),
                  border: Border.all(color: AppColors.royalGold.withValues(alpha: 0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Level ${localProgress.level}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.royalGold)),
                        Chip(
                          backgroundColor: AppColors.tokenGreen.withValues(alpha: 0.2),
                          label: Text(_leagueForTrophies(localProgress.trophies),
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.tokenGreen)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: xpInLevel / 250.0,
                      backgroundColor: Colors.white12,
                      color: AppColors.activeCyan,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 6),
                    Text('XP: ${localProgress.xp} ($xpInLevel / 250 to next level)',
                        style: const TextStyle(fontSize: 12)),
                    const Divider(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statCol('Matches', '${localProgress.totalMatches}'),
                        _statCol('Wins', '${localProgress.totalWins}'),
                        _statCol('Ulti Kuti', '${localProgress.totalKutiCaptures}'),
                        _statCol('Trophies', '${localProgress.trophies}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text('Recent Game Records', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 10),
              if (localProgress.localMatchHistory.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Abhi koi match record nahi hai. Pehla Kuti match khelein!'),
                  ),
                )
              else
                ...localProgress.localMatchHistory.map(
                  (m) => Card(
                    child: ListTile(
                      leading: Icon(
                        m['won'] == true ? Icons.emoji_events : Icons.sports_esports,
                        color: m['won'] == true ? AppColors.royalGold : Colors.white54,
                      ),
                      title: Text('${m['mode']} — ${m['won'] == true ? "VICTORY" : "COMPLETED"}'),
                      subtitle: Text('Ulti Kuti: ${m['kutiCount']} | Trophies: +${m['trophiesDelta']}'),
                      trailing: Text(
                        '${(m['coinsDelta'] as int) >= 0 ? "+" : ""}${m['coinsDelta']} Coins',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: (m['coinsDelta'] as int) >= 0 ? AppColors.tokenGreen : AppColors.kutiCrimson,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _statCol(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}
