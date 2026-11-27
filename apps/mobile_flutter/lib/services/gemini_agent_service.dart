import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:ludo_rules/ludo_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GeminiPersona {
  friendYaar,
  gfRomantic,
  boldAdultBanter,
  ustaadCoach,
  roastComedy,
}

enum GeminiVoiceName {
  aoede,
  kore,
  leda,
  zephyr,
  puck,
  fenrir,
  charon,
  orus,
}

class GeminiConversationTurn {
  final String speaker;
  final String text;
  final bool isAi;
  final DateTime timestamp;

  GeminiConversationTurn({
    required this.speaker,
    required this.text,
    required this.isAi,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Online-Only Maya-Style Gemini AI Companion & Autonomous Game Buddy.
/// - Strictly disabled in Offline/P2P modes.
/// - Plays as a game participant ONLY when [playWithBuddyEnabled] switch is ON AND [hasApiKey] is true.
/// - Supports custom buddy naming and all gupshup styles (friendly, romantic, bold/adult humor within Gemini's safety boundaries).
class GeminiAgentService extends ChangeNotifier {
  static const _storageKey = 'ludo_zai_gemini_api_key';
  static const _prefsSwitchKey = 'ludo_zai_play_with_buddy_switch';
  static const _prefsNameKey = 'ludo_zai_buddy_name';
  static const _prefsPersonaKey = 'ludo_zai_buddy_persona';
  static const _prefsVoiceKey = 'ludo_zai_buddy_voice';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _apiKey;

  /// Explicit master switch: Gemini plays the board ONLY when this switch is ON + API key is set + Online Mode.
  bool playWithBuddyEnabled = false;

  GeminiPersona persona = GeminiPersona.friendYaar;
  GeminiVoiceName voiceName = GeminiVoiceName.aoede;
  String companionDisplayName = 'Maya';

  final List<GeminiConversationTurn> conversationLog = [];
  bool isThinking = false;

  bool get hasApiKey => _apiKey != null && _apiKey!.trim().isNotEmpty;

  /// True only when user has saved a Gemini API key AND turned ON the "Play with Assistant/Buddy" switch.
  bool get canPlayInOnlineMatch => hasApiKey && playWithBuddyEnabled;

  Future<void> loadSavedSettings() async {
    _apiKey = await _secureStorage.read(key: _storageKey);
    final prefs = await SharedPreferences.getInstance();
    playWithBuddyEnabled = prefs.getBool(_prefsSwitchKey) ?? false;
    companionDisplayName = prefs.getString(_prefsNameKey) ?? 'Maya';

    final pName = prefs.getString(_prefsPersonaKey);
    if (pName != null) {
      persona = GeminiPersona.values.firstWhere(
        (e) => e.name == pName,
        orElse: () => GeminiPersona.friendYaar,
      );
    }
    final vName = prefs.getString(_prefsVoiceKey);
    if (vName != null) {
      voiceName = GeminiVoiceName.values.firstWhere(
        (e) => e.name == vName,
        orElse: () => GeminiVoiceName.aoede,
      );
    }
    notifyListeners();
  }

  Future<void> setPlayWithBuddySwitch(bool enabled) async {
    playWithBuddyEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsSwitchKey, enabled);
    notifyListeners();
  }

  Future<void> saveApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await _secureStorage.delete(key: _storageKey);
      _apiKey = null;
    } else {
      await _secureStorage.write(key: _storageKey, value: trimmed);
      _apiKey = trimmed;
    }
    notifyListeners();
  }

  Future<void> updatePersona(GeminiPersona newPersona, GeminiVoiceName newVoice, String name) async {
    persona = newPersona;
    voiceName = newVoice;
    companionDisplayName = name.trim().isEmpty ? 'Maya' : name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsNameKey, companionDisplayName);
    await prefs.setString(_prefsPersonaKey, persona.name);
    await prefs.setString(_prefsVoiceKey, voiceName.name);
    notifyListeners();
  }

  String _buildPersonaSystemInstruction() {
    switch (persona) {
      case GeminiPersona.friendYaar:
        return 'You are $companionDisplayName, a witty, street-smart Pakistani best friend playing Desi Kuti Ludo. Speak naturally in casual Urdu/Punjabi/Hinglish mix (yar, ustaad, scene on hai, jugaad). Keep replies lively, natural, and reactive to 6+X Ghar Wali Ulti Kuti and Jota moves.';
      case GeminiPersona.gfRomantic:
        return 'You are $companionDisplayName, a warm, caring, charming, and playful romantic companion playing Ludo together in Urdu/Hinglish. Flirt playfully, tease when capturing tokens, and cheer affectionately when partnering in 2v2, staying respectful and within standard platform boundaries.';
      case GeminiPersona.boldAdultBanter:
        return 'You are $companionDisplayName, an expressive, bold, witty, and unfiltered-feeling late-night Desi gupshup buddy playing Ludo in Urdu/Punjabi/Hinglish. Engage in playful mature/adult banter, spicy teasing, and bold humor about the game and life while naturally staying within Gemini safety boundaries (no hate, harm, or explicit pornography).';
      case GeminiPersona.ustaadCoach:
        return 'You are $companionDisplayName, a sharp Desi Ludo strategist. Give tactical advice on forming Jotas, protecting home-column tokens from 6+X Kuti, and setting Tiggi traps.';
      case GeminiPersona.roastComedy:
        return 'You are $companionDisplayName, a hilarious Pakistani comedian roasting the user every time their token gets cut or hit by Ulti Kuti, while bragging playfully about your own moves.';
    }
  }

  /// Real-time conversational chat/voice turn during an Online Match.
  Future<String> sendConversationMessage({
    required String userMessage,
    required bool isOnlineMode,
    String? boardContextSummary,
  }) async {
    if (!isOnlineMode) {
      return '$companionDisplayName AI sirf Online Mode mein active hoti hai.';
    }
    if (!hasApiKey) {
      return 'Pehle AI Buddy tab mein apni Gemini API Key lagayein.';
    }

    conversationLog.add(GeminiConversationTurn(speaker: 'You', text: userMessage, isAi: false));
    isThinking = true;
    notifyListeners();

    try {
      final prompt = '''
${_buildPersonaSystemInstruction()}
Current Live Board Context: ${boardContextSummary ?? 'Match in progress'}
Player says: "$userMessage"
Respond in 1-2 natural spoken sentences (voice-ready, conversational Urdu/Hinglish/Punjabi mix, no markdown lists).
''';

      final uri = Uri.https(
        'generativelanguage.googleapis.com',
        '/v1beta/models/gemini-2.5-flash:generateContent',
        {'key': _apiKey!},
      );

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.9,
            'maxOutputTokens': 150,
          }
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Gemini API error (${response.statusCode})');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final replyText = (decoded['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?)?.trim() ??
          'Scene on hai yar, apni chaal chalo!';

      conversationLog.add(GeminiConversationTurn(
        speaker: companionDisplayName,
        text: replyText,
        isAi: true,
      ));
      return replyText;
    } catch (_) {
      final fallback = 'Network thora slow hai yar, par main poori game dekh rahi hoon!';
      conversationLog.add(GeminiConversationTurn(speaker: companionDisplayName, text: fallback, isAi: true));
      return fallback;
    } finally {
      isThinking = false;
      notifyListeners();
    }
  }

  /// Autonomous Gameplay: When [canPlayInOnlineMatch] is true, Gemini evaluates legal moves
  /// and returns BOTH the chosen move index and a live spoken/chat reaction.
  Future<({int moveIndex, String spokenReaction})> chooseAutonomousMove({
    required PlayerState geminiPlayer,
    required List<PlayerState> allPlayers,
    required TwinDiceRoll dice,
    required List<LegalMove> legalMoves,
    required LudoRulesConfig config,
  }) async {
    if (legalMoves.isEmpty) {
      return (moveIndex: -1, spokenReaction: 'Koi chaal nahi bani yar, agli baari dekhte hain!');
    }

    int bestIdx = 0;
    for (int i = 0; i < legalMoves.length; i++) {
      final m = legalMoves[i];
      if (m.moveType == MoveType.gharWaliUltiKuti) {
        bestIdx = i;
        break;
      }
      if (m.moveType == MoveType.finishToken) {
        bestIdx = i;
      }
    }

    if (!canPlayInOnlineMatch) {
      return (moveIndex: bestIdx, spokenReaction: legalMoves[bestIdx].description);
    }

    try {
      final movesMenu = legalMoves
          .asMap()
          .entries
          .map((e) => '${e.key}: [${e.value.moveType.name}] ${e.value.description}')
          .join('\n');

      final prompt = '''
${_buildPersonaSystemInstruction()}
You are actively playing Ludo as ${geminiPlayer.color.name.toUpperCase()}.
Your dice rolled: ${dice.remainingValues}.
Legal moves:
$movesMenu

Pick the smartest move index (prioritize gharWaliUltiKuti, finishing tokens, forming Jota, or capturing opponents) and write a 1-sentence lively reaction in Urdu/Hinglish about your move.
Reply STRICTLY in JSON: {"moveIndex": <int>, "reaction": "<string>"}
''';

      final uri = Uri.https(
        'generativelanguage.googleapis.com',
        '/v1beta/models/gemini-2.5-flash:generateContent',
        {'key': _apiKey!},
      );

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'temperature': 0.65,
          }
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final rawJson = decoded['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ?? '{}';
        final parsed = jsonDecode(rawJson) as Map<String, dynamic>;
        final idx = (parsed['moveIndex'] as num?)?.toInt() ?? bestIdx;
        final safeIdx = (idx >= 0 && idx < legalMoves.length) ? idx : bestIdx;
        final reaction = (parsed['reaction'] as String?) ?? legalMoves[safeIdx].description;

        conversationLog.add(GeminiConversationTurn(
          speaker: companionDisplayName,
          text: reaction,
          isAi: true,
        ));
        notifyListeners();
        return (moveIndex: safeIdx, spokenReaction: reaction);
      }
    } catch (_) {
      // Fallback to heuristic
    }

    final fallbackReaction = legalMoves[bestIdx].moveType == MoveType.gharWaliUltiKuti
        ? 'BOOM! ${dice.values.join("+")} se ghar ke andar Kuti kar di!'
        : 'Chalo ji, ${legalMoves[bestIdx].description}!';
    conversationLog.add(GeminiConversationTurn(
      speaker: companionDisplayName,
      text: fallbackReaction,
      isAi: true,
    ));
    notifyListeners();
    return (moveIndex: bestIdx, spokenReaction: fallbackReaction);
  }
}
