import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'local_progress_service.dart';

class CashMaalStoreService {
  final SupabaseClient _db = Supabase.instance.client;

  bool get isGmailAuthenticated {
    final u = _db.auth.currentUser;
    return u != null && !u.isAnonymous && (u.email?.isNotEmpty ?? false);
  }

  Future<Map<String, dynamic>> fetchWalletAndProfile(LocalProgressService localProgress) async {
    if (!isGmailAuthenticated) {
      return {
        'isGuest': true,
        'coins': localProgress.coins,
        'gems': localProgress.gems,
        'trophies': localProgress.trophies,
        'level': localProgress.level,
        'xp': localProgress.xp,
        'league': 'Guest (Device Save)',
      };
    }

    final uid = _db.auth.currentUser!.id;
    final wallet = await _db.from('wallets').select().eq('user_id', uid).maybeSingle();
    final profile = await _db.from('profiles').select().eq('id', uid).maybeSingle();
    return {
      'isGuest': false,
      'email': _db.auth.currentUser!.email,
      'coins': wallet?['coins'] ?? 2500,
      'gems': wallet?['gems'] ?? 25,
      'trophies': profile?['trophies'] ?? 0,
      'level': profile?['level'] ?? 1,
      'xp': profile?['xp'] ?? 0,
      'league': profile?['league'] ?? 'Bronze',
    };
  }

  /// Opens CashMaal automated checkout (100 PKR = 1000 Coins, 100 PKR = 100 Gems).
  /// Strictly requires Gmail registration.
  Future<void> startBuyOrder({required String assetType, required int assetAmount}) async {
    if (!isGmailAuthenticated) {
      throw Exception('Buy/Sell ke liye pehle Gmail ID se register/login karein.');
    }
    final res = await _db.functions.invoke('cashmaal-create-buy', body: {
      'asset_type': assetType,
      'asset_amount': assetAmount,
    });
    final data = res.data as Map<String, dynamic>?;
    if (data?['error'] != null) throw Exception(data!['error']);
    final url = Uri.parse(data!['checkout_url'] as String);
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  /// Converts Gems -> Coins (1 Gem = 10 Coins). Works for both Gmail users (DB) and Guest users (Device).
  Future<void> exchangeGemsToCoins({
    required int gemsToSpend,
    required LocalProgressService localProgress,
  }) async {
    if (!isGmailAuthenticated) {
      await localProgress.convertGuestGemsToCoins(gemsToSpend);
      return;
    }
    await _db.rpc('exchange_gems_to_coins', params: {
      'p_user_id': _db.auth.currentUser!.id,
      'p_gems_to_spend': gemsToSpend,
    });
  }

  /// Sells Coins or Gems with 30% fee deducted and sends Net PKR directly to user's CashMaal account.
  Future<String> submitDirectCashMaalWithdraw({
    required String assetType,
    required int assetAmount,
    required String cashmaalAccount,
  }) async {
    if (!isGmailAuthenticated) {
      throw Exception('Sell & CashMaal Withdraw ke liye pehle Gmail ID se login karein.');
    }
    final res = await _db.functions.invoke('cashmaal-auto-sell', body: {
      'asset_type': assetType,
      'asset_amount': assetAmount,
      'cashmaal_account': cashmaalAccount,
    });
    final data = res.data as Map<String, dynamic>?;
    if (data?['error'] != null) throw Exception(data!['error']);
    return data?['message'] as String? ?? 'CashMaal auto-withdraw initiated!';
  }

  Future<String> startAdsterraRewardSession(String rewardType) async {
    final res = await _db.functions.invoke('verify-adsterra-reward', body: {
      'action': 'start',
      'reward_type': rewardType,
    });
    final data = res.data as Map<String, dynamic>?;
    if (data?['error'] != null) throw Exception(data!['error']);
    final adUrl = data?['ad_url'] as String? ?? '';
    if (adUrl.isNotEmpty) {
      await launchUrl(Uri.parse(adUrl), mode: LaunchMode.externalApplication);
    }
    return data!['session_id'] as String;
  }

  Future<Map<String, dynamic>> claimAdsterraReward(String sessionId) async {
    final res = await _db.functions.invoke('verify-adsterra-reward', body: {
      'action': 'claim',
      'session_id': sessionId,
    });
    final data = res.data as Map<String, dynamic>?;
    if (data?['error'] != null) throw Exception(data!['error']);
    return data!;
  }

  Future<Map<String, dynamic>> claimFreeGift(String claimType) async {
    final res = await _db.functions.invoke('claim-free-reward', body: {'claim_type': claimType});
    final data = res.data as Map<String, dynamic>?;
    if (data?['error'] != null) throw Exception(data!['error']);
    return data!;
  }
}
