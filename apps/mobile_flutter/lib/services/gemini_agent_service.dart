import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:ludo_rules/ludo_rules.dart';

enum GeminiPersona {
  friendYaar,
  gfRomantic,
  ustaadCoach,
  roastComedy,
}

enum GeminiVoiceName {
  aoede, // Female warm
  kore, // Female energetic
  leda, // Female soft
  zephyr, // Female bright
  puck, // Male witty
  fenrir, // Male deep
  charon, // Male calm
  orus, // Male friendly
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

/// Online-Only Maya-Style Gemini AI Companion & Autonomous Game Player.
/// - Strictly disabled in Offline/P2P modes.
/// - Stores user's Gemini API key in hardware-encrypted Android Keystore.
/// - Can hold real voice/text conversations in Urdu/Punjabi/Hinglish/English AND
///   autonomously play Ludo (as Opponent or 2v2 Partner) while commenting on its moves.
class GeminiAgentService extends ChangeNotifier {
  static const _storageKey = 'ludo_zai_gemini_api_key';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _apiKey;
  bool isEnabledInOnlineMode = true;
  bool autoPlayAsParticipant = true;
  GeminiPersona persona = GeminiPersona.friendYaar;
  GeminiVoiceName voiceName = GeminiVoiceName.aoede;
  String companionDisplayName = 'Maya';

  final List<GeminiConversationTurn> conversationLog = [];
  bool isThinking = false;

  bool get hasApiKey => _apiKey != null && _apiKey!.trim().isNotEmpty;

  Future<void> loadSavedSettings() async {
    _apiKey = await _secureStorage.read(key: _storageKey);
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

  void updatePersona(GeminiPersona newPersona, GeminiVoiceName newVoice, String name) {
    persona = newPersona;
    voiceName = newVoice;
    companionDisplayName = name.trim().isEmpty ? 'Maya' : name.trim();
    notifyListeners();
  }

  String _buildPersonaSystemInstruction() {
    switch (persona) {
      case GeminiPersona.friendYaar:
        return 'You are $companionDisplayName, a witty street-smart Pakistani best friend playing Desi Kuti Ludo. Speak naturally in casual Urdu/Punjabi/Hinglish mix (yar, ustaad, scene on hai). Keep replies punchy, lively, and reactive to 6+X Ghar Wali Ulti Kuti and Jota moves.';
      case GeminiPersona.gfRomantic:
        return 'You are $companionDisplayName, a caring, playful, and affectionate companion playing Ludo together in Urdu/Hinglish. Tease gently when capturing tokens and cheer warmly when partnering in 2v2.';
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
      return 'Gemini AI Companion sirf Online Mode mein active hota hai.';
    }
    if (!hasApiKey) {
      return 'Pehle Settings mein apni Gemini API Key lagayein.';
    }

    conversationLog.add(GeminiConversationTurn(speaker: 'You', text: userMessage, isAi: false));
    isThinking = true;
    notifyListeners();

    try {
      final prompt = '''
${_buildPersonaSystemInstruction()}
Current Live Board Context: ${boardContextSummary ?? 'Match in progress'}
Player says: "$userMessage"
Respond in 1-2 natural spoken sentences (voice-ready, no markdown lists).
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
            'temperature': 0.85,
            'maxOutputTokens': 140,
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
    } catch (e) {
      final fallback = 'Network thora slow hai yar, par main game dekh rahi hoon!';
      conversationLog.add(GeminiConversationTurn(speaker: companionDisplayName, text: fallback, isAi: true));
      return fallback;
    } finally {
      isThinking = false;
      notifyListeners();
    }
  }

  /// Autonomous Gameplay: When Gemini is playing as Opponent or 2v2 Partner,
  /// evaluates legal moves (prioritizing 6+X Ghar Wali Ulti Kuti, finishes, and captures)
  /// and returns BOTH the chosen move index and a live spoken/chat reaction!
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

    // Heuristic priority baseline (ensures instant valid fallback even on slow network)
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

    if (!hasApiKey) {
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
            'temperature': 0.6,
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
      // Fallback to heuristic bestIdx
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
