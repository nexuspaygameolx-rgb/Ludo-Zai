import 'dart:math';
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

  void _openCreateCustomRuleSheet() {
    final titleCtrl = TextEditingController();
    String trigger = 'on_capture';
    String condition = 'has_finished_token';
    String action = 'grant_extra_turn';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create New Ilaqai / Custom Rule',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.royalGold)),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Rule Name (e.g. Sahiwal Double Bonus)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: trigger,
                decoration: const InputDecoration(labelText: 'Step 1: Trigger (Kab Ho?)', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'on_capture', child: Text('Goti Katne Par (On Capture)')),
                  DropdownMenuItem(value: 'on_home_entry', child: Text('Ghar Line Mein Jane Par (On Home Entry)')),
                  DropdownMenuItem(value: 'on_dice_roll', child: Text('Specific Dice Roll Par')),
                ],
                onChanged: (v) => setSheetState(() => trigger = v ?? 'on_capture'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: condition,
                decoration: const InputDecoration(labelText: 'Step 2: Condition (Shart?)', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'has_finished_token', child: Text('Kam Az Kam 1 Goti Puggi Ho')),
                  DropdownMenuItem(value: 'is_kuti', child: Text('Goti Ulti Kuti Ho')),
                ],
                onChanged: (v) => setSheetState(() => condition = v ?? 'has_finished_token'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: action,
                decoration: const InputDecoration(labelText: 'Step 3: Action (Asar?)', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'grant_extra_turn', child: Text('Extra Turn Mile')),
                  DropdownMenuItem(value: 'flip_to_kuti', child: Text('Goti Ulti Kuti Ban Jaye')),
                ],
                onChanged: (v) => setSheetState(() => action = v ?? 'grant_extra_turn'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_circle),
                  label: const Text('Add Rule & Generate Share Code'),
                  onPressed: () {
                    final code = List.generate(6, (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[Random().nextInt(32)]).join();
                    final newRule = CustomRuleDefinition(
                      id: code,
                      name: titleCtrl.text.trim().isEmpty ? 'Desi Rule ($code)' : '${titleCtrl.text.trim()} [$code]',
                      trigger: trigger,
                      condition: condition,
                      action: action,
                    );
                    setState(() {
                      _cfg = _cfg.copyWith(customRules: [..._cfg.customRules, newRule]);
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Desi Rule Switches & Builder'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _cfg),
            child: const Text('APPLY', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.royalGold)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.royalGold,
        foregroundColor: AppColors.darkBg,
        icon: const Icon(Icons.add),
        label: const Text('New Rule', style: TextStyle(fontWeight: FontWeight.w900)),
        onPressed: _openCreateCustomRuleSheet,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
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
          const SizedBox(height: 14),
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
          if (_cfg.customRules.isNotEmpty) ...[
            const Divider(height: 24),
            const Text('User-Created Custom Rules:', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.royalGold)),
            ..._cfg.customRules.map(
              (r) => SwitchListTile(
                title: Text(r.name),
                subtitle: Text('${r.trigger} -> ${r.condition} -> ${r.action}'),
                value: r.enabled,
                onChanged: (v) {
                  setState(() {
                    _cfg = _cfg.copyWith(
                      customRules: _cfg.customRules
                          .map((item) => item.id == r.id
                              ? CustomRuleDefinition(
                                  id: item.id,
                                  name: item.name,
                                  trigger: item.trigger,
                                  condition: item.condition,
                                  conditionValue: item.conditionValue,
                                  action: item.action,
                                  enabled: v,
                                )
                              : item)
                          .toList(),
                    );
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
