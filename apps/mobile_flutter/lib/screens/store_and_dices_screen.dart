import 'package:flutter/material.dart';
import '../core/config/remote_config_service.dart';
import '../core/theme/app_theme.dart';
import '../services/cashmaal_store_service.dart';
import '../services/local_progress_service.dart';

class StoreAndDicesScreen extends StatefulWidget {
  final RemoteConfigService remoteConfig;
  final LocalProgressService localProgress;

  const StoreAndDicesScreen({
    super.key,
    required this.remoteConfig,
    required this.localProgress,
  });

  @override
  State<StoreAndDicesScreen> createState() => _StoreAndDicesScreenState();
}

class _StoreAndDicesScreenState extends State<StoreAndDicesScreen> {
  final CashMaalStoreService _store = CashMaalStoreService();
  final TextEditingController _sellAmountCtrl = TextEditingController(text: '1000');
  final TextEditingController _cashmaalAccCtrl = TextEditingController();
  final TextEditingController _gemsConvertCtrl = TextEditingController(text: '10');
  String _sellAsset = 'coins';
  String? _pendingAdSessionId;

  double _calculateNetWithdrawPkr() {
    final cfg = widget.remoteConfig;
    final amt = double.tryParse(_sellAmountCtrl.text) ?? 0;
    final unitRate = _sellAsset == 'coins'
        ? (cfg.coinsBuyRatePer1000 / 1000.0)
        : (cfg.gemsBuyRatePer100 / 100.0);
    final grossPkr = amt * unitRate;
    return grossPkr * ((100.0 - cfg.sellFeePercent) / 100.0);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.remoteConfig;
    final isRegistered = _store.isGmailAuthenticated;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CashMaal Store, Gems & 3D Dices'),
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
            // TAB 1: Buy, Gems->Coins, & CashMaal Direct Auto-Withdraw
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!isRegistered)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.kutiCrimson.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.kutiCrimson),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Guest Mode Active (Device Save)',
                          style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.kutiCrimson),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Aap bina login offline aur online khel sakte hain, lekin Buy/Sell aur CashMaal Withdraw ke liye aik dafa Gmail ID se register karna lazmi hai.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.login),
                          label: const Text('Register / Login with Gmail'),
                          onPressed: () => widget.localProgress.signInWithGmailAndSync(),
                        ),
                      ],
                    ),
                  ),

                // Buy Coins & Gems (100 PKR = 1,000 Coins | 100 PKR = 100 Gems)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Buy Coins & Gems (CashMaal Instant)',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text('Rate: ${cfg.coinsBuyRatePer1000.toInt()} PKR = 1,000 Coins  |  ${cfg.gemsBuyRatePer100.toInt()} PKR = 100 Gems'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isRegistered
                                    ? () => _store.startBuyOrder(assetType: 'coins', assetAmount: 1000)
                                    : null,
                                child: const Text('1,000 Coins (100 Rs)'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.activeCyan),
                                onPressed: isRegistered
                                    ? () => _store.startBuyOrder(assetType: 'gems', assetAmount: 100)
                                    : null,
                                child: const Text('100 Gems (100 Rs)'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Convert Gems -> Coins (1 Gem = 10 Coins)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Gems Se Coins Buy Karein (1 Gem = 10 Coins)',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _gemsConvertCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Gems Amount (e.g. 10 = 100 Coins)',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () async {
                                final g = int.tryParse(_gemsConvertCtrl.text) ?? 0;
                                await _store.exchangeGemsToCoins(
                                  gemsToSpend: g,
                                  localProgress: widget.localProgress,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$g Gems se ${g * 10} Coins mil gaye!')),
                                  );
                                }
                              },
                              child: const Text('Convert'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Sell Coins or Gems -> 30% Fee -> Auto CashMaal Direct Account Withdraw
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sell & Direct CashMaal Withdraw',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text(
                          'Sell Rate: ${cfg.sellFeePercent.toInt()}% Admin Fee kategi — 1,000 Coins = ${cfg.coinsSellNetPkrPer1000.toInt()} PKR | 100 Gems = ${cfg.gemsSellNetPkrPer100.toInt()} PKR',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.royalGold),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _sellAsset,
                          items: const [
                            DropdownMenuItem(value: 'coins', child: Text('Sell Coins (1,000 Coins -> 70 PKR)')),
                            DropdownMenuItem(value: 'gems', child: Text('Sell Gems (100 Gems -> 70 PKR)')),
                          ],
                          onChanged: (v) => setState(() => _sellAsset = v ?? 'coins'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _sellAmountCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Step 1: Select / Enter Amount to Sell',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _cashmaalAccCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Step 2: Enter Your CashMaal Account Email / ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.tokenGreen.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Net CashMaal Payout (After 30% Fee):', style: TextStyle(fontSize: 12)),
                              Text(
                                '${_calculateNetWithdrawPkr().toStringAsFixed(2)} PKR',
                                style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.tokenGreen),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.tokenGreen,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.account_balance_wallet),
                            label: const Text('Auto Withdraw to CashMaal'),
                            onPressed: isRegistered
                                ? () async {
                                    final msg = await _store.submitDirectCashMaalWithdraw(
                                      assetType: _sellAsset,
                                      assetAmount: int.tryParse(_sellAmountCtrl.text) ?? 0,
                                      cashmaalAccount: _cashmaalAccCtrl.text,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                                    }
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // TAB 2: Free Coins & Adsterra Ads
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  leading: const Icon(Icons.card_giftcard, color: AppColors.royalGold),
                  title: const Text('4-Hour Free Coins Box'),
                  trailing: ElevatedButton(
                    onPressed: () => _store.claimFreeGift('four_hour_gift'),
                    child: const Text('CLAIM'),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.play_circle_fill, color: AppColors.kutiCrimson),
                  title: const Text('Watch Adsterra Ad -> Reward'),
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
                    child: Text(_pendingAdSessionId == null ? 'WATCH AD' : 'CLAIM'),
                  ),
                ),
              ],
            ),

            // TAB 3: 3D Dices
            ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                ListTile(
                  leading: Icon(Icons.casino, color: AppColors.royalGold, size: 32),
                  title: Text('Pakistani Truck Art 3D Dice'),
                  subtitle: Text('Level 1 -> Level 5 (Dhol Fireworks Kuti VFX)'),
                ),
                ListTile(
                  leading: Icon(Icons.local_fire_department, color: AppColors.kutiCrimson, size: 32),
                  title: Text('Ulti Kuti Dragon Fire 3D Dice'),
                  subtitle: Text('Level 1 -> Level 5 (Inferno Crown Smash VFX)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
