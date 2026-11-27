import 'package:flutter/material.dart';
import 'package:ludo_rules/ludo_rules.dart';
import '../core/theme/app_theme.dart';
import '../services/community_rules_service.dart';

class CustomRulesStudioScreen extends StatefulWidget {
  final LudoRulesConfig initialConfig;
  final CommunityRulesService communityRulesService;

  const CustomRulesStudioScreen({
    super.key,
    required this.initialConfig,
    required this.communityRulesService,
  });

  @override
  State<CustomRulesStudioScreen> createState() => _CustomRulesStudioScreenState();
}

class _CustomRulesStudioScreenState extends State<CustomRulesStudioScreen> {
  late LudoRulesConfig _cfg;
  final TextEditingController _nlInstructionCtrl = TextEditingController();
  final TextEditingController _nlTitleCtrl = TextEditingController();
  bool _creatingRule = false;

  @override
  void initState() {
    super.initState();
    _cfg = widget.initialConfig;
    widget.communityRulesService.syncPendingAndFetchGlobalRules();
  }

  LudoRulesConfig _buildFinalConfigWithSwitches() {
    return _cfg.copyWith(
      customRules: widget.communityRulesService.getActiveCustomRuleDefinitions(),
    );
  }

  Future<void> _submitNaturalLanguageRule() async {
    final text = _nlInstructionCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _creatingRule = true);
    try {
      final created = await widget.communityRulesService.createFromNaturalLanguage(
        instruction: text,
        customTitle: _nlTitleCtrl.text,
      );
      _nlInstructionCtrl.clear();
      _nlTitleCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              created.syncedToCloud
                  ? 'Naya Rule "${created.title}" ban kar database mein save ho gaya aur switch ON hai!'
                  : 'Naya Rule "${created.title}" ka switch ON ho gaya! Online hote hi database par sab ke liye save ho jayega.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingRule = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.communityRulesService,
      builder: (context, _) {
        final communityRules = widget.communityRulesService.rules;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Desi & Community Rule Switches'),
            actions: [
              IconButton(
                icon: const Icon(Icons.sync, color: AppColors.activeCyan),
                tooltip: 'Sync Community Rules',
                onPressed: () => widget.communityRulesService.syncPendingAndFetchGlobalRules(),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, _buildFinalConfigWithSwitches()),
                child: const Text('APPLY', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.royalGold)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Natural-Language Rule Box: User writes plain instructions -> App creates switch & syncs to DB
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(colors: [Color(0xFF1F2A48), Color(0xFF141B2D)]),
                  border: Border.all(color: AppColors.royalGold.withValues(alpha: 0.7), width: 1.4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_fix_high, color: AppColors.royalGold),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Apna Naya Rule Likhein (Simple Language)',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.royalGold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sirf aam zuban mein apni shart likhein—APK khud isay rule mein badal kar neeche switch bana degi aur online hone par database mein save kar degi:',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nlTitleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Rule Ka Chhota Naam (Optional, e.g. Sahiwal Kuti Bonus)',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nlInstructionCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText:
                            'Maslan: "Jab 1 goti puggi ho aur opponent ki goti katu to extra baari mile" ya "12 aane par goti ulti kuti ban jaye"',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_task),
                        label: Text(_creatingRule ? 'Saving Rule...' : 'Save Rule & Show Switch'),
                        onPressed: _creatingRule ? null : _submitNaturalLanguageRule,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Community & User Natural-Language Rule Switches (Auto-synced across all users)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Community & Your Custom Rule Switches',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.activeCyan),
                  ),
                  if (widget.communityRulesService.isSyncing)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 6),
              if (communityRules.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('Abhi koi naya custom rule nahi hai. Upar likh kar pehla rule banayein!'),
                  ),
                )
              else
                ...communityRules.map((item) {
                  final isOn = widget.communityRulesService.enabledRuleCodes.contains(item.ruleCode);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: SwitchListTile(
                      activeThumbColor: AppColors.activeCyan,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                          Icon(
                            item.syncedToCloud ? Icons.cloud_done : Icons.cloud_upload,
                            size: 15,
                            color: item.syncedToCloud ? AppColors.tokenGreen : AppColors.royalGold,
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '"${item.naturalInstruction}"
By ${item.creatorName} • Code: ${item.ruleCode}',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      value: isOn,
                      onChanged: (v) => widget.communityRulesService.toggleRuleSwitch(item.ruleCode, v),
                    ),
                  );
                }),

              const Divider(height: 26),
              const Text('Built-in Desi Kuti Switches', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 8),
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
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('Kuti Mode (Double Dice + Ghar Wali Ulti Kuti)'),
                value: _cfg.kutiMode,
                onChanged: (v) => setState(() => _cfg = _cfg.copyWith(kutiMode: v)),
              ),
              SwitchListTile(
                title: const Text('1 Goti Remaining = 1 Dice Auto-Switch'),
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
                      child: Text('1. Delayed Remaining Kill'),
                    ),
                    DropdownMenuItem(
                      value: TiggiVsJotaRule.fullTiggiCut,
                      child: Text('2. Poori Tiggi Cut'),
                    ),
                    DropdownMenuItem(
                      value: TiggiVsJotaRule.tiggiShield,
                      child: Text('3. Tiggi Full Shield'),
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
      },
    );
  }
}
