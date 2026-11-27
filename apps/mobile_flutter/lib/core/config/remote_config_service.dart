import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RemoteConfigService extends ChangeNotifier {
  bool maintenanceMode = false;
  String maintenanceMessage = '';
  bool geminiAiGlobalEnabled = true;

  // Dynamic Adsterra Config loaded from Admin Panel
  bool adsterraEnabled = true;
  String adsterraDirectLinkUrl = '';
  String adsterraRewardedAdUrl = '';
  int adsterraRewardCoins = 500;
  int adsterraRewardGems = 5;
  int adsterraChestSkipMinutes = 30;

  // Exact Pricing: 100 PKR = 1,000 Coins | 100 PKR = 100 Gems | 1 Gem = 10 Coins | 30% Sell Fee
  bool cashmaalEnabled = true;
  double coinsBuyRatePer1000 = 100.0;
  double gemsBuyRatePer100 = 100.0;
  int gemsToCoinsRatio = 10;
  double sellFeePercent = 30.0;
  int minSellCoins = 1000;
  int minSellGems = 100;

  double get coinsSellNetPkrPer1000 => coinsBuyRatePer1000 * ((100.0 - sellFeePercent) / 100.0);
  double get gemsSellNetPkrPer100 => gemsBuyRatePer100 * ((100.0 - sellFeePercent) / 100.0);

  Map<String, dynamic> defaultRulesJson = {};

  Future<void> fetchFromBackend() async {
    try {
      final res = await Supabase.instance.client.functions.invoke('get-public-config');
      final data = (res.data as Map<String, dynamic>?)?['config'] as Map<String, dynamic>?;
      if (data == null) return;

      maintenanceMode = data['maintenance_mode'] as bool? ?? false;
      maintenanceMessage = data['maintenance_message'] as String? ?? '';
      geminiAiGlobalEnabled = data['gemini_ai_global_enabled'] as bool? ?? true;

      final ad = data['adsterra_config'] as Map<String, dynamic>? ?? {};
      adsterraEnabled = ad['enabled'] as bool? ?? true;
      adsterraDirectLinkUrl = ad['direct_link_url'] as String? ?? '';
      adsterraRewardedAdUrl = ad['rewarded_ad_url'] as String? ?? '';
      adsterraRewardCoins = (ad['reward_coins'] as num?)?.toInt() ?? 500;
      adsterraRewardGems = (ad['reward_gems'] as num?)?.toInt() ?? 5;
      adsterraChestSkipMinutes = (ad['chest_skip_minutes'] as num?)?.toInt() ?? 30;

      final cm = data['cashmaal_public_config'] as Map<String, dynamic>? ?? {};
      cashmaalEnabled = cm['enabled'] as bool? ?? true;
      coinsBuyRatePer1000 = (cm['coins_buy_rate_pkr_per_1000'] as num?)?.toDouble() ?? 100.0;
      gemsBuyRatePer100 = (cm['gems_buy_rate_pkr_per_100'] as num?)?.toDouble() ?? 100.0;
      gemsToCoinsRatio = (cm['gems_to_coins_ratio'] as num?)?.toInt() ?? 10;
      sellFeePercent = (cm['sell_fee_percent'] as num?)?.toDouble() ?? 30.0;
      minSellCoins = (cm['min_sell_coins'] as num?)?.toInt() ?? 1000;
      minSellGems = (cm['min_sell_gems'] as num?)?.toInt() ?? 100;

      defaultRulesJson = data['default_rules'] as Map<String, dynamic>? ?? {};
      notifyListeners();
    } catch (_) {
      // Offline / guest fallback
    }
  }
}
