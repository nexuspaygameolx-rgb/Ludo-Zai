import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:ludo_rules/ludo_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityNaturalRule {
  final String ruleCode;
  final String title;
  final String naturalInstruction;
  final String creatorName;
  final CustomRuleDefinition definition;
  final bool syncedToCloud;

  CommunityNaturalRule({
    required this.ruleCode,
    required this.title,
    required this.naturalInstruction,
    required this.creatorName,
    required this.definition,
    required this.syncedToCloud,
  });

  Map<String, dynamic> toJson() => {
        'rule_code': ruleCode,
        'title': title,
        'natural_instruction': naturalInstruction,
        'creator_name': creatorName,
        'synced_to_cloud': syncedToCloud,
        'definition': definition.toJson(),
      };

  factory CommunityNaturalRule.fromJson(Map<String, dynamic> json) {
    final defMap = json['definition'] as Map<String, dynamic>?;
    final def = defMap != null
        ? CustomRuleDefinition.fromJson(defMap)
        : CustomRuleDefinition(
            id: json['rule_code'] as String? ?? 'RULE',
            name: json['title'] as String? ?? 'Community Rule',
            trigger: json['trigger_type'] as String? ?? 'on_capture',
            condition: json['condition_type'] as String? ?? 'has_finished_token',
            conditionValue: (json['condition_value'] as num?)?.toInt(),
            action: json['action_type'] as String? ?? 'grant_extra_turn',
            enabled: false,
          );
    return CommunityNaturalRule(
      ruleCode: json['rule_code'] as String? ?? def.id,
      title: json['title'] as String? ?? def.name,
      naturalInstruction: json['natural_instruction'] as String? ?? def.name,
      creatorName: json['creator_name'] as String? ?? 'Desi Player',
      definition: def,
      syncedToCloud: json['synced_to_cloud'] as bool? ?? true,
    );
  }
}

/// Compiles plain Urdu/English/Punjabi instructions into executable Ludo rules,
/// displays instant toggle switches to the user, auto-syncs offline-created rules
/// to the database whenever online, and fetches all users' shared rules globally.
class CommunityRulesService extends ChangeNotifier {
  static const _localRulesKey = 'ludo_zai_nl_rules_v1';
  static const _enabledCodesKey = 'ludo_zai_enabled_nl_rule_codes_v1';

  final List<CommunityNaturalRule> rules = [];
  final Set<String> enabledRuleCodes = {};
  bool isSyncing = false;

  Future<void> initializeAndSync() async {
    await _loadFromDevice();
    await syncPendingAndFetchGlobalRules();
  }

  Future<void> _loadFromDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getString(_localRulesKey);
    if (rawList != null) {
      final decoded = jsonDecode(rawList) as List<dynamic>;
      rules
        ..clear()
        ..addAll(decoded.map((e) => CommunityNaturalRule.fromJson(e as Map<String, dynamic>)));
    }
    final savedEnabled = prefs.getStringList(_enabledCodesKey) ?? [];
    enabledRuleCodes
      ..clear()
      ..addAll(savedEnabled);
    notifyListeners();
  }

  Future<void> _saveToDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localRulesKey, jsonEncode(rules.map((r) => r.toJson()).toList()));
    await prefs.setStringList(_enabledCodesKey, enabledRuleCodes.toList());
    notifyListeners();
  }

  /// Compiles plain language text (e.g. "Jab 1 goti puggi ho aur opponent ki goti katu to extra turn mile")
  /// into an executable rule, enables its toggle switch immediately, and auto-saves to cloud DB.
  Future<CommunityNaturalRule> createFromNaturalLanguage({
    required String instruction,
    String? customTitle,
  }) async {
    final clean = instruction.trim();
    final lower = clean.toLowerCase();

    String trigger = 'on_capture';
    if (lower.contains('ghar') || lower.contains('home') || lower.contains('lane') || lower.contains('ander')) {
      trigger = 'on_home_entry';
    } else if (lower.contains('dice') ||
        lower.contains('daana') ||
        lower.contains('chakka') ||
        lower.contains('6') ||
        lower.contains('12') ||
        lower.contains('roll')) {
      trigger = 'on_dice_roll';
    }

    String condition = 'has_finished_token';
    int? conditionValue;
    if (lower.contains('kuti') || lower.contains('ulti') || lower.contains('reverse')) {
      condition = 'is_kuti';
    } else if (lower.contains('12') || lower.contains('double six') || lower.contains('do chakkay')) {
      condition = 'dice_sum_exact';
      conditionValue = 12;
    } else if (lower.contains('6') || lower.contains('chakka')) {
      condition = 'dice_sum_exact';
      conditionValue = 6;
    }

    String action = 'grant_extra_turn';
    if (lower.contains('kuti') || lower.contains('ulti') || lower.contains('reverse') || lower.contains('palat')) {
      action = 'flip_to_kuti';
    }

    final code = List.generate(6, (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[Random().nextInt(32)]).join();
    final title = (customTitle != null && customTitle.trim().isNotEmpty)
        ? customTitle.trim()
        : (clean.length > 36 ? '${clean.substring(0, 36)}...' : clean);

    final user = Supabase.instance.client.auth.currentUser;
    final creatorName = user?.email?.split('@').first ?? 'Desi Player';

    final def = CustomRuleDefinition(
      id: code,
      name: title,
      trigger: trigger,
      condition: condition,
      conditionValue: conditionValue,
      action: action,
      enabled: true,
    );

    bool uploaded = false;
    try {
      await Supabase.instance.client.from('community_nl_rules').upsert({
        'rule_code': code,
        'creator_id': user?.id,
        'creator_name': creatorName,
        'title': title,
        'natural_instruction': clean,
        'trigger_type': trigger,
        'condition_type': condition,
        'condition_value': conditionValue,
        'action_type': action,
        'is_approved': true,
      }, onConflict: 'rule_code');
      uploaded = true;
    } catch (_) {
      // Offline right now: mark syncedToCloud = false so it auto-syncs as soon as online
      uploaded = false;
    }

    final item = CommunityNaturalRule(
      ruleCode: code,
      title: title,
      naturalInstruction: clean,
      creatorName: creatorName,
      definition: def,
      syncedToCloud: uploaded,
    );

    rules.insert(0, item);
    enabledRuleCodes.add(code);
    await _saveToDevice();
    return item;
  }

  /// Auto-uploads any offline-created rules to Supabase and fetches all users' shared rules.
  Future<void> syncPendingAndFetchGlobalRules() async {
    if (isSyncing) return;
    isSyncing = true;
    notifyListeners();

    try {
      final db = Supabase.instance.client;
      final user = db.auth.currentUser;

      // 1. Push any local rules created while offline
      for (int i = 0; i < rules.length; i++) {
        final r = rules[i];
        if (!r.syncedToCloud) {
          await db.from('community_nl_rules').upsert({
            'rule_code': r.ruleCode,
            'creator_id': user?.id,
            'creator_name': r.creatorName,
            'title': r.title,
            'natural_instruction': r.naturalInstruction,
            'trigger_type': r.definition.trigger,
            'condition_type': r.definition.condition,
            'condition_value': r.definition.conditionValue,
            'action_type': r.definition.action,
            'is_approved': true,
          }, onConflict: 'rule_code');
          rules[i] = CommunityNaturalRule(
            ruleCode: r.ruleCode,
            title: r.title,
            naturalInstruction: r.naturalInstruction,
            creatorName: r.creatorName,
            definition: r.definition,
            syncedToCloud: true,
          );
        }
      }

      // 2. Fetch all global community rules created by all users
      final rows = await db
          .from('community_nl_rules')
          .select()
          .eq('is_approved', true)
          .order('created_at', ascending: false)
          .limit(100);

      final existingCodes = rules.map((e) => e.ruleCode).toSet();
      for (final row in (rows as List<dynamic>)) {
        final map = row as Map<String, dynamic>;
        final code = map['rule_code'] as String? ?? '';
        if (code.isNotEmpty && !existingCodes.contains(code)) {
          rules.add(CommunityNaturalRule.fromJson(map));
          existingCodes.add(code);
        }
      }
      await _saveToDevice();
    } catch (_) {
      // Remain smoothly on local cache if offline
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> toggleRuleSwitch(String ruleCode, bool enabled) async {
    if (enabled) {
      enabledRuleCodes.add(ruleCode);
    } else {
      enabledRuleCodes.remove(ruleCode);
    }
    await _saveToDevice();
  }

  /// Returns all currently toggled-ON community natural-language rules ready for [LudoRuleEngine].
  List<CustomRuleDefinition> getActiveCustomRuleDefinitions() {
    return rules
        .where((r) => enabledRuleCodes.contains(r.ruleCode))
        .map((r) => CustomRuleDefinition(
              id: r.definition.id,
              name: r.title,
              trigger: r.definition.trigger,
              condition: r.definition.condition,
              conditionValue: r.definition.conditionValue,
              action: r.definition.action,
              enabled: true,
            ))
        .toList();
  }
}
