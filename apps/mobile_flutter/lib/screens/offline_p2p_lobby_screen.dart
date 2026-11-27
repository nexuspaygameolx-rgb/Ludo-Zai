import 'package:flutter/material.dart';
import 'package:ludo_rules/ludo_rules.dart';
import '../core/theme/app_theme.dart';
import '../services/gemini_agent_service.dart';
import '../services/local_progress_service.dart';
import '../services/offline_p2p_service.dart';
import 'game_arena_screen.dart';

class OfflineP2PLobbyScreen extends StatefulWidget {
  final OfflineP2PService p2pService;
  final LudoRulesConfig rulesConfig;
  final GeminiAgentService geminiService;
  final LocalProgressService localProgress;

  const OfflineP2PLobbyScreen({
    super.key,
    required this.p2pService,
    required this.rulesConfig,
    required this.geminiService,
    required this.localProgress,
  });

  @override
  State<OfflineP2PLobbyScreen> createState() => _OfflineP2PLobbyScreenState();
}

class _OfflineP2PLobbyScreenState extends State<OfflineP2PLobbyScreen> {
  final TextEditingController _nameCtrl = TextEditingController(text: 'Desi Player');
  OfflineTransportMode _mode = OfflineTransportMode.nearbyAuto;

  void _enterOfflineMatch() {
    final players = widget.p2pService.players.isNotEmpty
        ? widget.p2pService.players
        : [
            PlayerState(
              playerId: 'host_0',
              name: _nameCtrl.text.trim(),
              color: PlayerColor.red,
              tokens: List.generate(4, (i) => TokenState(id: 'red_$i', owner: PlayerColor.red)),
            ),
            PlayerState(
              playerId: 'pass_1',
              name: 'Friend (Pass & Play)',
              color: PlayerColor.green,
              tokens: List.generate(4, (i) => TokenState(id: 'green_$i', owner: PlayerColor.green)),
            ),
          ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameArenaScreen(
          isOnlineMode: false,
          isOfflineP2P: widget.p2pService.isConnected,
          rulesConfig: widget.rulesConfig,
          initialPlayers: players,
          geminiService: widget.geminiService,
          p2pService: widget.p2pService,
          localProgress: widget.localProgress,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.p2pService,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Apne Mobile Par Khelein (No Internet)')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Bina internet ke 2 se 4 dost apne-apne mobile par 3D Ludo, live mic audio, aur text chat ke saath khelein:',
                style: TextStyle(fontSize: 13.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Your Display Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<OfflineTransportMode>(
                initialValue: _mode,
                decoration: const InputDecoration(labelText: 'Offline Connection Bridge', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                    value: OfflineTransportMode.nearbyAuto,
                    child: Text('1. Auto Nearby (Wi-Fi Direct + BLE — 1-Tap Connect)'),
                  ),
                  DropdownMenuItem(
                    value: OfflineTransportMode.hotspotLan,
                    child: Text('2. Local Hotspot LAN (No Data — 100m Long Range)'),
                  ),
                  DropdownMenuItem(
                    value: OfflineTransportMode.bluetoothFallback,
                    child: Text('3. Bluetooth Fallback Mode'),
                  ),
                ],
                onChanged: (v) => setState(() => _mode = v ?? OfflineTransportMode.nearbyAuto),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.wifi_tethering),
                      label: const Text('Create Room (Host)'),
                      onPressed: () => widget.p2pService.startHosting(
                        hostName: _nameCtrl.text.trim(),
                        config: widget.rulesConfig,
                        mode: _mode,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.activeCyan),
                      icon: const Icon(Icons.radar),
                      label: const Text('Scan Nearby'),
                      onPressed: () => widget.p2pService.startDiscovery(
                        joinerName: _nameCtrl.text.trim(),
                        mode: _mode,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.tokenGreen, foregroundColor: Colors.white),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  widget.p2pService.isConnected
                      ? 'Start Connected Multi-Phone Match (${widget.p2pService.players.length} Players)'
                      : 'Start Local Pass & Play Match',
                ),
                onPressed: _enterOfflineMatch,
              ),
              const SizedBox(height: 20),
              if (widget.p2pService.discoveredRooms.isNotEmpty) ...[
                const Text('Nearby Tables Found:', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ...widget.p2pService.discoveredRooms.entries.map(
                  (e) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.phone_android, color: AppColors.tokenGreen),
                      title: Text(e.value),
                      trailing: ElevatedButton(
                        onPressed: () => widget.p2pService.joinDiscoveredRoom(e.key, _nameCtrl.text.trim()),
                        child: const Text('JOIN'),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
