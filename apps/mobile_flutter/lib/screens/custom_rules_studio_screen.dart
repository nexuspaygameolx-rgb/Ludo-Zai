import 'package:flutter/material.dart';
import 'package:ludo_rules/ludo_rules.dart';
import '../core/theme/app_theme.dart';

class CustomRulesStudioScreen extends StatefulWidget {
  final LudoRulesConfig initialConfig;
  const CustomRulesStudioScreen({super.key, required this.initialConfig});

  @override
  State<CustomRulesStudioScreen> createState() => _CustomRulesStudioScreenState();
}

class _CustomRulesStudioScreenState extends State<CustomRulesStudioScreen> {
  late LudoRulesConfig _cfg;

  @override
  void initState() {
    super.initState();
    _cfg = widget.initialConfig;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Desi Rule Switches & Presets'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _cfg),
            child: const Text('APPLY', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.royalGold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Regional Presets
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Punjab Kuti Special'),
                selected: _cfg.kutiMode && _cfg.tiggiRule == TiggiVsJotaRule.delayedRemainingKill,
                onSelected: (_) => setState(() => _cfg = LudoRulesConfig.punjabKutiSpecial()),
              ),
              ChoiceChip(
                label: const Text('Sindh Master'),
                selected: !_cfg.kutiMode && _cfg.katiBaghairGharBand,
                onSelected: (_) => setState(() => _cfg = LudoRulesConfig.sindhMaster()),
              ),
              ChoiceChip(
                label: const Text('Classic Ludo STAR'),
                selected: !_cfg.kutiMode && !_cfg.jotaEnabled,
                onSelected: (_) => setState(() => _cfg = LudoRulesConfig.classicLudoStar()),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('Kuti Mode (Double Dice + Ghar Wali Ulti Kuti)'),
            subtitle: const Text('6+X exact distance par home-column mein kuti aur hamesha ulti chaal'),
            value: _cfg.kutiMode,
            onChanged: (v) => setState(() => _cfg = _cfg.copyWith(kutiMode: v)),
          ),
          SwitchListTile(
            title: const Text('1 Goti Remaining = 1 Dice Auto-Switch'),
            subtitle: const Text('3 gotiyan pugne ke baad aakhri goti par sirf 1 dice chalega'),
            value: _cfg.autoSingleDiceOnLastToken,
            onChanged: (v) => setState(() => _cfg = _cfg.copyWith(autoSingleDiceOnLastToken: v)),
          ),
          SwitchListTile(
            title: const Text('Ulti Kuti Sweep Kill (Raaste Ki Saari Gotiyan)'),
            subtitle: const Text('ON = Raaste ki saari gotiyan marein | OFF = Sirf rukne wale dabbe par'),
            value: _cfg.kutiKillScope == KutiKillScope.sweepKill,
            onChanged: (v) => setState(() => _cfg = _cfg.copyWith(
                  kutiKillScope: v ? KutiKillScope.sweepKill : KutiKillScope.landingKill,
                )),
          ),
          SwitchListTile(
            title: const Text('Kuti Safe-Zone Bypass (Pakki Gotiyan Bhi Marein)'),
            value: _cfg.kutiBypassSafeZones,
            onChanged: (v) => setState(() => _cfg = _cfg.copyWith(kutiBypassSafeZones: v)),
          ),
          SwitchListTile(
            title: const Text('Kuti Vulnerability (Kuti Khud Bhi Mar Sakti Hai)'),
            value: _cfg.kutiVulnerable,
            onChanged: (v) => setState(() => _cfg = _cfg.copyWith(kutiVulnerable: v)),
          ),
          SwitchListTile(
            title: const Text('Jota (Doubling Protection)'),
            value: _cfg.jotaEnabled,
            onChanged: (v) => setState(() => _cfg = _cfg.copyWith(jotaEnabled: v)),
          ),
          ListTile(
            title: const Text('3 Gotiyan (Tiggi) vs Opponent Jota Rule'),
            subtitle: DropdownButton<TiggiVsJotaRule>(
              isExpanded: true,
              value: _cfg.tiggiRule,
              items: const [
                DropdownMenuItem(
                  value: TiggiVsJotaRule.delayedRemainingKill,
                  child: Text('1. Delayed Remaining Kill (1 ya Jota nikalte hi baqi mar jayein)'),
                ),
                DropdownMenuItem(
                  value: TiggiVsJotaRule.fullTiggiCut,
                  child: Text('2. Poori Tiggi Cut (Teeno foran mar jayein)'),
                ),
                DropdownMenuItem(
                  value: TiggiVsJotaRule.tiggiShield,
                  child: Text('3. Tiggi Full Shield (Jota nahi maar sakta)'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _cfg = _cfg.copyWith(tiggiRule: v));
              },
            ),
          ),
          SwitchListTile(
            title: const Text('Kati Baghair Ghar Band (Mandatory Kill)'),
            value: _cfg.katiBaghairGharBand,
            onChanged: (v) => setState(() => _cfg = _cfg.copyWith(katiBaghairGharBand: v)),
          ),
        ],
      ),
    );
  }
}
