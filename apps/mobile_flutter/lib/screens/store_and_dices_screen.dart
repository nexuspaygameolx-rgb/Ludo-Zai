import 'package:flutter/material.dart';
import '../core/config/remote_config_service.dart';
import '../core/theme/app_theme.dart';
import '../services/cashmaal_store_service.dart';

class StoreAndDicesScreen extends StatefulWidget {
  final RemoteConfigService remoteConfig;
  const StoreAndDicesScreen({super.key, required this.remoteConfig});

  @override
  State<StoreAndDicesScreen> createState() => _StoreAndDicesScreenState();
}

class _StoreAndDicesScreenState extends State<StoreAndDicesScreen> {
  final CashMaalStoreService _store = CashMaalStoreService();
  final TextEditingController _sellAmountCtrl = TextEditingController(text: '10000');
  final TextEditingController _cashmaalAccCtrl = TextEditingController();
  String _sellAsset = 'coins';
  String? _pendingAdSessionId;

  @override
  Widget build(BuildContext context) {
    final cfg = widget.remoteConfig;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CashMaal Store, Ads & 3D Dices'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Buy / Sell'),
              Tab(text: 'Free & Ads'),
              Tab(text: '3D Dices'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: CashMaal Automated Buy & Sell
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Buy From Admin Store (CashMaal Auto-Deposit)',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Buy Rate: ${cfg.coinsBuyRatePer1000} PKR / 1,000 Coins | ${cfg.gemsBuyRatePer10} PKR / 10 Gems'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _store.startBuyOrder(assetType: 'coins', assetAmount: 10000),
                                child: const Text('Buy 10,000 Coins'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.activeCyan),
                                onPressed: () => _store.startBuyOrder(assetType: 'gems', assetAmount: 100),
                                child: const Text('Buy 100 Gems'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sell To Admin Store (CashMaal Auto-Payout)',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Sell Rate: ${cfg.coinsSellRatePer1000} PKR / 1,000 Coins | ${cfg.gemsSellRatePer10} PKR / 10 Gems | ${cfg.trophiesSellRatePer100} PKR / 100 Trophies'),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _sellAsset,
                          items: const [
                            DropdownMenuItem(value: 'coins', child: Text('Sell Coins')),
                            DropdownMenuItem(value: 'gems', child: Text('Sell Gems')),
                            DropdownMenuItem(value: 'trophies', child: Text('Sell Trophies')),
                          ],
                          onChanged: (v) => setState(() => _sellAsset = v ?? 'coins'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _sellAmountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Amount to Sell'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _cashmaalAccCtrl,
                          decoration: const InputDecoration(labelText: 'Your CashMaal Account Email / ID'),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.tokenGreen, foregroundColor: Colors.white),
                            onPressed: () async {
                              final msg = await _store.submitSellOrder(
                                assetType: _sellAsset,
                                assetAmount: int.tryParse(_sellAmountCtrl.text) ?? 0,
                                cashmaalAccount: _cashmaalAccCtrl.text,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                              }
                            },
                            child: const Text('Submit Instant Cashout'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // TAB 2: Ludo STAR Free Coins & Adsterra Rewarded Ads
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  leading: const Icon(Icons.card_giftcard, color: AppColors.royalGold),
                  title: const Text('4-Hour Free Coins Box'),
                  subtitle: const Text('Claim 400 Free Coins every 4 hours'),
                  trailing: ElevatedButton(
                    onPressed: () => _store.claimFreeGift('four_hour_gift'),
                    child: const Text('CLAIM'),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today, color: AppColors.tokenGreen),
                  title: const Text('7-Day Daily Login Streak'),
                  subtitle: const Text('Escalating Coins + Day 7 Magical Gems'),
                  trailing: ElevatedButton(
                    onPressed: () => _store.claimFreeGift('daily_streak'),
                    child: const Text('CLAIM'),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.play_circle_fill, color: AppColors.kutiCrimson),
                  title: const Text('Watch Adsterra Ad -> Instant Reward'),
                  subtitle: Text('Earn +${cfg.adsterraRewardCoins} Coins or +${cfg.adsterraRewardGems} Gems'),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      if (_pendingAdSessionId == null) {
                        final sid = await _store.startAdsterraRewardSession('coins');
                        setState(() => _pendingAdSessionId = sid);
                      } else {
                        await _store.claimAdsterraReward(_pendingAdSessionId!);
                        setState(() => _pendingAdSessionId = null);
                      }
                    },
                    child: Text(_pendingAdSessionId == null ? 'WATCH AD' : 'CLAIM REWARD'),
                  ),
                ),
              ],
            ),

            // TAB 3: Upgradable 3D Dices (Level 1 to 5)
            ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                ListTile(
                  leading: Icon(Icons.casino, color: AppColors.royalGold, size: 32),
                  title: Text('Pakistani Truck Art 3D Dice'),
                  subtitle: Text('Upgradable Level 1 -> Level 5 (Dhol Fireworks Kuti VFX)'),
                ),
                ListTile(
                  leading: Icon(Icons.local_fire_department, color: AppColors.kutiCrimson, size: 32),
                  title: Text('Ulti Kuti Dragon Fire 3D Dice'),
                  subtitle: Text('Upgradable Level 1 -> Level 5 (Inferno Crown Smash VFX)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
