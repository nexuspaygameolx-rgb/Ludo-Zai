import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Saves complete player progress locally on device when playing WITHOUT Gmail login
/// (both Offline & Online Guest Mode), and syncs/merges progress to database once the
/// user registers/signs in with their Gmail ID.
class LocalProgressService extends ChangeNotifier {
  static const _prefsKey = 'ludo_zai_guest_progress_v1';
  static const _mergedFlagKey = 'ludo_zai_guest_merged_uid';

  int coins = 2500;
  int gems = 25;
  int trophies = 0;
  int xp = 0;
  int level = 1;
  int totalMatches = 0;
  int totalWins = 0;
  int totalKutiCaptures = 0;
  List<Map<String, dynamic>> localMatchHistory = [];

  bool get isGmailRegistered {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null && !user.isAnonymous && (user.email?.isNotEmpty ?? false);
  }

  String? get userEmail => Supabase.instance.client.auth.currentUser?.email;

  Future<void> loadFromDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      coins = (map['coins'] as num?)?.toInt() ?? 2500;
      gems = (map['gems'] as num?)?.toInt() ?? 25;
      trophies = (map['trophies'] as num?)?.toInt() ?? 0;
      xp = (map['xp'] as num?)?.toInt() ?? 0;
      level = (map['level'] as num?)?.toInt() ?? 1;
      totalMatches = (map['totalMatches'] as num?)?.toInt() ?? 0;
      totalWins = (map['totalWins'] as num?)?.toInt() ?? 0;
      totalKutiCaptures = (map['totalKutiCaptures'] as num?)?.toInt() ?? 0;
      localMatchHistory = (map['localMatchHistory'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
    }
    notifyListeners();
  }

  Future<void> _saveToDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'coins': coins,
        'gems': gems,
        'trophies': trophies,
        'xp': xp,
        'level': level,
        'totalMatches': totalMatches,
        'totalWins': totalWins,
        'totalKutiCaptures': totalKutiCaptures,
        'localMatchHistory': localMatchHistory.take(50).toList(),
      }),
    );
    notifyListeners();
  }

  /// Updates device-saved progress for Guest users after any Offline or Online match.
  Future<void> recordGuestMatchResult({
    required bool won,
    required int coinsDelta,
    required int gemsDelta,
    required int trophiesDelta,
    required int xpGain,
    required int kutiCount,
    required String modeName,
  }) async {
    coins = (coins + coinsDelta).clamp(0, 999999999);
    gems = (gems + gemsDelta).clamp(0, 999999999);
    trophies = (trophies + trophiesDelta).clamp(0, 999999999);
    xp += xpGain;
    level = (xp ~/ 250) + 1;
    totalMatches += 1;
    if (won) totalWins += 1;
    totalKutiCaptures += kutiCount;

    localMatchHistory.insert(0, {
      'mode': modeName,
      'won': won,
      'coinsDelta': coinsDelta,
      'trophiesDelta': trophiesDelta,
      'kutiCount': kutiCount,
      'playedAt': DateTime.now().toIso8601String(),
    });
    await _saveToDevice();
  }

  /// Converts Gems -> Coins locally for Guest players (1 Gem = 10 Coins).
  Future<void> convertGuestGemsToCoins(int gemsToSpend) async {
    if (gemsToSpend <= 0 || gems < gemsToSpend) {
      throw Exception('Insufficient Gems');
    }
    gems -= gemsToSpend;
    coins += gemsToSpend * 10;
    await _saveToDevice();
  }

  /// Sign in with Gmail (Google OAuth) and sync local guest progress to Supabase DB.
  Future<void> signInWithGmailAndSync() async {
    await Supabase.instance.client.auth.signInWithOAuth(OAuthProvider.google);
  }

  Future<void> syncDeviceProgressToCloudIfNeeded() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyMergedUid = prefs.getString(_mergedFlagKey);
    if (alreadyMergedUid == user.id) return;

    if (xp > 0 || trophies > 0 || totalMatches > 0) {
      await Supabase.instance.client.rpc('merge_guest_progress_once', params: {
        'p_user_id': user.id,
        'p_guest_xp': xp,
        'p_guest_trophies': trophies,
        'p_guest_matches': totalMatches,
        'p_guest_wins': totalWins,
        'p_guest_kuti': totalKutiCaptures,
      });
    }
    await prefs.setString(_mergedFlagKey, user.id);
    notifyListeners();
  }
}
