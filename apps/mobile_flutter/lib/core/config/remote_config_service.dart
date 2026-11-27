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

  // Dynamic CashMaal Config loaded from Admin Panel
  bool cashmaalEnabled = true;
  double coinsBuyRatePer1000 = 15.0;
  double coinsSellRatePer1000 = 11.0;
  double gemsBuyRatePer10 = 25.0;
  double gemsSellRatePer10 = 18.0;
  double trophiesSellRatePer100 = 20.0;
  int minSellCoins = 10000;
  int minSellGems = 100;
  int minSellTrophies = 500;

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
      coinsBuyRatePer1000 = (cm['coins_buy_rate_pkr_per_1000'] as num?)?.toDouble() ?? 15.0;
      coinsSellRatePer1000 = (cm['coins_sell_rate_pkr_per_1000'] as num?)?.toDouble() ?? 11.0;
      gemsBuyRatePer10 = (cm['gems_buy_rate_pkr_per_10'] as num?)?.toDouble() ?? 25.0;
      gemsSellRatePer10 = (cm['gems_sell_rate_pkr_per_10'] as num?)?.toDouble() ?? 18.0;
      trophiesSellRatePer100 = (cm['trophies_sell_rate_pkr_per_100'] as num?)?.toDouble() ?? 20.0;
      minSellCoins = (cm['min_sell_coins'] as num?)?.toInt() ?? 10000;
      minSellGems = (cm['min_sell_gems'] as num?)?.toInt() ?? 100;
      minSellTrophies = (cm['min_sell_trophies'] as num?)?.toInt() ?? 500;

      defaultRulesJson = data['default_rules'] as Map<String, dynamic>? ?? {};
      notifyListeners();
    } catch (_) {
      // Fallback to cached defaults when offline
    }
  }
}
