import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class CashMaalStoreService {
  final SupabaseClient _db = Supabase.instance.client;

  Future<Map<String, dynamic>> fetchWalletAndProfile() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return {'coins': 2500, 'gems': 25, 'trophies': 0, 'level': 1, 'xp': 0};

    final wallet = await _db.from('wallets').select().eq('user_id', uid).maybeSingle();
    final profile = await _db.from('profiles').select().eq('id', uid).maybeSingle();
    return {
      'coins': wallet?['coins'] ?? 2500,
      'gems': wallet?['gems'] ?? 25,
      'trophies': profile?['trophies'] ?? 0,
      'level': profile?['level'] ?? 1,
      'xp': profile?['xp'] ?? 0,
      'league': profile?['league'] ?? 'Bronze',
    };
  }

  /// Opens CashMaal automated checkout to buy Coins or Gems from Admin Store.
  Future<void> startBuyOrder({required String assetType, required int assetAmount}) async {
    final res = await _db.functions.invoke('cashmaal-create-buy', body: {
      'asset_type': assetType,
      'asset_amount': assetAmount,
    });
    final data = res.data as Map<String, dynamic>?;
    if (data?['error'] != null) throw Exception(data!['error']);
    final url = Uri.parse(data!['checkout_url'] as String);
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  /// Sells user's won Coins, Gems, or Trophies back to Admin Store via CashMaal auto-payout.
  Future<String> submitSellOrder({
    required String assetType,
    required int assetAmount,
    required String cashmaalAccount,
  }) async {
    final res = await _db.functions.invoke('cashmaal-auto-sell', body: {
      'asset_type': assetType,
      'asset_amount': assetAmount,
      'cashmaal_account': cashmaalAccount,
    });
    final data = res.data as Map<String, dynamic>?;
    if (data?['error'] != null) throw Exception(data!['error']);
    return data?['message'] as String? ?? 'Sell order submitted!';
  }

  /// Starts and claims a server-verified Adsterra Rewarded Ad session.
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

  Future<void> upgradeDice(String diceId) async {
    final res = await _db.functions.invoke('upgrade-dice', body: {'dice_id': diceId});
    final data = res.data as Map<String, dynamic>?;
    if (data?['error'] != null) throw Exception(data!['error']);
  }
}
