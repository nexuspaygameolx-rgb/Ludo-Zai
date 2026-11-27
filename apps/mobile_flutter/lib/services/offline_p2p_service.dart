import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:ludo_rules/ludo_rules.dart';
import 'package:nearby_connections/nearby_connections.dart';

enum OfflineTransportMode {
  nearbyAuto, // Wi-Fi Direct + BLE via Google Nearby Connections
  hotspotLan, // Local Wi-Fi Hotspot WebSocket (no mobile data needed)
  bluetoothFallback,
}

class LocalChatMessage {
  final String senderName;
  final String text;
  final bool isSticker;
  final DateTime timestamp;

  LocalChatMessage({
    required this.senderName,
    required this.text,
    this.isSticker = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Multi-Device Offline P2P Engine ("Apne Apne Mobile Par" with zero internet).
/// - Host device runs authoritative [LudoRuleEngine] & RNG so joiners cannot cheat.
/// - Streams live compressed audio packets + instant text chat over local link.
/// - Strictly isolated from online CashMaal wallet balances.
class OfflineP2PService extends ChangeNotifier {
  static const String serviceId = 'com.ludozai.offline.p2p';

  OfflineTransportMode transportMode = OfflineTransportMode.nearbyAuto;
  bool isHost = false;
  bool isConnected = false;
  bool micEnabled = true;
  bool pushToTalkMode = false;
  final Set<String> mutedEndpointIds = {};

  final Map<String, String> discoveredRooms = {}; // endpointId -> roomName
  final Map<String, String> connectedPeers = {}; // endpointId -> playerName
  final List<LocalChatMessage> chatMessages = [];

  HttpServer? _lanServer;
  final List<WebSocket> _lanClients = [];
  WebSocket? _lanHostSocket;

  // Authoritative game state held on Host and broadcast to all phones
  LudoRulesConfig rulesConfig = LudoRulesConfig.punjabKutiSpecial();
  List<PlayerState> players = [];
  int activeSeatIndex = 0;
  TwinDiceRoll? activeDice;
  PlayerColor localPlayerColor = PlayerColor.red;

  void Function(Uint8List pcmBytes, String fromEndpoint)? onIncomingVoiceAudio;

  /// Host creates an offline multi-device room on their phone.
  Future<void> startHosting({
    required String hostName,
    required LudoRulesConfig config,
    OfflineTransportMode mode = OfflineTransportMode.nearbyAuto,
  }) async {
    isHost = true;
    transportMode = mode;
    rulesConfig = config;
    localPlayerColor = PlayerColor.red;

    players = [
      PlayerState(
        playerId: 'host_0',
        name: hostName,
        color: PlayerColor.red,
        tokens: List.generate(4, (i) => TokenState(id: 'red_$i', owner: PlayerColor.red)),
      ),
    ];

    if (mode == OfflineTransportMode.hotspotLan) {
      await _startLanWebSocketServer();
    } else {
      await Nearby().startAdvertising(
        '$hostName's Kuti Table',
        Strategy.P2P_STAR,
        onConnectionInitiated: (id, info) {
          Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (endId, payload) => _handleNearbyPayload(endId, payload),
          );
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            isConnected = true;
            connectedPeers[id] = 'Player ${connectedPeers.length + 2}';
            _addSeatForPeer(id, connectedPeers[id]!);
            _broadcastFullState();
            notifyListeners();
          }
        },
        onDisconnected: (id) {
          // 15-second grace period before removing disconnected peer
          Timer(const Duration(seconds: 15), () {
            if (!connectedPeers.containsKey(id)) return;
            connectedPeers.remove(id);
            notifyListeners();
          });
        },
        serviceId: serviceId,
      );
    }
    notifyListeners();
  }

  /// Joiner scans nearby phones without internet.
  Future<void> startDiscovery({
    required String joinerName,
    OfflineTransportMode mode = OfflineTransportMode.nearbyAuto,
  }) async {
    isHost = false;
    transportMode = mode;
    discoveredRooms.clear();

    await Nearby().startDiscovery(
      joinerName,
      Strategy.P2P_STAR,
      onEndpointFound: (id, name, svcId) {
        discoveredRooms[id] = name;
        notifyListeners();
      },
      onEndpointLost: (id) {
        discoveredRooms.remove(id);
        notifyListeners();
      },
      serviceId: serviceId,
    );
    notifyListeners();
  }

  Future<void> joinDiscoveredRoom(String endpointId, String myName) async {
    await Nearby().requestConnection(
      myName,
      endpointId,
      onConnectionInitiated: (id, info) {
        Nearby().acceptConnection(
          id,
          onPayLoadRecieved: (endId, payload) => _handleNearbyPayload(endId, payload),
        );
      },
      onConnectionResult: (id, status) {
        if (status == Status.CONNECTED) {
          isConnected = true;
          connectedPeers[id] = 'Host';
          sendJsonPacket({'type': 'hello', 'name': myName});
          notifyListeners();
        }
      },
      onDisconnected: (id) {
        isConnected = false;
        notifyListeners();
      },
    );
  }

  void _addSeatForPeer(String peerId, String peerName) {
    if (players.length >= 4) return;
    const order = [PlayerColor.red, PlayerColor.green, PlayerColor.yellow, PlayerColor.blue];
    final color = order[players.length];
    players.add(
      PlayerState(
        playerId: peerId,
        name: peerName,
        color: color,
        tokens: List.generate(4, (i) => TokenState(id: '${color.name}_$i', owner: color)),
      ),
    );
  }

  /// Host rolls dice and broadcasts to all phones.
  void hostRollDice() {
    if (!isHost || players.isEmpty) return;
    final active = players[activeSeatIndex];
    activeDice = DiceHelper.roll(active, rulesConfig);
    final moves = LudoRuleEngine.getLegalMoves(
      activePlayer: active,
      allPlayers: players,
      dice: activeDice!,
      config: rulesConfig,
    );
    if (moves.isEmpty) {
      activeDice = null;
      activeSeatIndex = (activeSeatIndex + 1) % players.length;
    }
    _broadcastFullState();
    notifyListeners();
  }

  /// Executes a move (either locally on Host or by sending move intent from Joiner to Host).
  void requestOrExecuteMove(int moveIndex) {
    if (!isHost) {
      sendJsonPacket({'type': 'move_intent', 'moveIndex': moveIndex});
      return;
    }
    if (activeDice == null) return;
    final active = players[activeSeatIndex];
    final moves = LudoRuleEngine.getLegalMoves(
      activePlayer: active,
      allPlayers: players,
      dice: activeDice!,
      config: rulesConfig,
    );
    if (moveIndex < 0 || moveIndex >= moves.length) return;

    final chosen = moves[moveIndex];
    final res = LudoRuleEngine.executeMove(
      activePlayer: active,
      allPlayers: players,
      move: chosen,
      config: rulesConfig,
    );
    players = res.updatedPlayers;
    activeDice = activeDice!.markUsed(chosen.diceUsedIndices);

    if (activeDice!.allUsed) {
      final rolledSix = activeDice!.values.contains(6);
      activeDice = null;
      if (!res.grantBonusTurn && !rolledSix) {
        activeSeatIndex = (activeSeatIndex + 1) % players.length;
      }
    }
    _broadcastFullState();
    notifyListeners();
  }

  /// Sends live text chat or Desi sticker across connected phones without internet.
  void sendChatMessage(String senderName, String text, {bool isSticker = false}) {
    chatMessages.add(LocalChatMessage(senderName: senderName, text: text, isSticker: isSticker));
    sendJsonPacket({
      'type': 'chat',
      'senderName': senderName,
      'text': text,
      'isSticker': isSticker,
    });
    notifyListeners();
  }

  /// Streams compressed mic audio frame to all connected local phones.
  void sendVoiceAudioFrame(Uint8List audioBytes) {
    if (!micEnabled || !isConnected) return;
    final header = Uint8List.fromList([0xA1]); // 0xA1 = Audio Packet prefix
    final frame = Uint8List(header.length + audioBytes.length)
      ..setAll(0, header)
      ..setAll(1, audioBytes);

    for (final endpointId in connectedPeers.keys) {
      Nearby().sendBytesPayload(endpointId, frame);
    }
    for (final ws in _lanClients) {
      ws.add(frame);
    }
    _lanHostSocket?.add(frame);
  }

  void sendJsonPacket(Map<String, dynamic> map) {
    final bytes = Uint8List.fromList([0x7B, ...utf8.encode(jsonEncode(map))]);
    for (final endpointId in connectedPeers.keys) {
      Nearby().sendBytesPayload(endpointId, bytes);
    }
    for (final ws in _lanClients) {
      ws.add(bytes);
    }
    _lanHostSocket?.add(bytes);
  }

  void _broadcastFullState() {
    if (!isHost) return;
    sendJsonPacket({
      'type': 'state_sync',
      'rules': rulesConfig.toJson(),
      'activeSeatIndex': activeSeatIndex,
      'dice': activeDice == null ? null : {'values': activeDice!.values, 'used': activeDice!.used},
      'players': players.map((p) => p.toJson()).toList(),
    });
  }

  void _handleNearbyPayload(String endpointId, Payload payload) {
    final bytes = payload.bytes;
    if (bytes == null || bytes.isEmpty) return;

    if (bytes[0] == 0xA1) {
      if (!mutedEndpointIds.contains(endpointId)) {
        onIncomingVoiceAudio?.call(bytes.sublist(1), endpointId);
      }
      return;
    }

    final raw = utf8.decode(bytes.sublist(1));
    final msg = jsonDecode(raw) as Map<String, dynamic>;
    final type = msg['type'] as String?;

    if (type == 'hello' && isHost) {
      final name = msg['name'] as String? ?? 'Friend';
      connectedPeers[endpointId] = name;
      final pIdx = players.indexWhere((p) => p.playerId == endpointId);
      if (pIdx != -1) {
        players[pIdx] = players[pIdx].copyWith(name: name);
      }
      _broadcastFullState();
      notifyListeners();
    } else if (type == 'move_intent' && isHost) {
      if (players[activeSeatIndex].playerId == endpointId) {
        requestOrExecuteMove(msg['moveIndex'] as int);
      }
    } else if (type == 'chat') {
      chatMessages.add(LocalChatMessage(
        senderName: msg['senderName'] as String? ?? 'Player',
        text: msg['text'] as String? ?? '',
        isSticker: msg['isSticker'] as bool? ?? false,
      ));
      if (isHost) sendJsonPacket(msg); // Relay to other peers
      notifyListeners();
    } else if (type == 'state_sync' && !isHost) {
      rulesConfig = LudoRulesConfig.fromJson(msg['rules'] as Map<String, dynamic>);
      activeSeatIndex = msg['activeSeatIndex'] as int? ?? 0;
      final d = msg['dice'] as Map<String, dynamic>?;
      activeDice = d == null
          ? null
          : TwinDiceRoll(
              values: (d['values'] as List<dynamic>).cast<int>(),
              used: (d['used'] as List<dynamic>).cast<bool>(),
            );
      players = (msg['players'] as List<dynamic>)
          .map((e) => PlayerState.fromJson(e as Map<String, dynamic>))
          .toList();
      final me = players.where((p) => p.playerId != 'host_0').lastOrNull;
      if (me != null) localPlayerColor = me.color;
      notifyListeners();
    }
  }

  Future<void> _startLanWebSocketServer() async {
    _lanServer = await HttpServer.bind(InternetAddress.anyIPv4, 4545);
    _lanServer!.transform(WebSocketTransformer()).listen((WebSocket ws) {
      _lanClients.add(ws);
      final peerId = 'lan_${_lanClients.length}';
      _addSeatForPeer(peerId, 'Wi-Fi Player ${_lanClients.length + 1}');
      _broadcastFullState();
      ws.listen((data) {
        if (data is List<int>) {
          _handleNearbyPayload(peerId, Payload(bytes: Uint8List.fromList(data)));
        }
      }, onDone: () => _lanClients.remove(ws));
    });
  }

  Future<void> stopAll() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    await _lanServer?.close(force: true);
    _lanClients.clear();
    isConnected = false;
    notifyListeners();
  }
}
