import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/gemini_agent_service.dart';

class GeminiSettingsScreen extends StatefulWidget {
  final GeminiAgentService geminiService;
  const GeminiSettingsScreen({super.key, required this.geminiService});

  @override
  State<GeminiSettingsScreen> createState() => _GeminiSettingsScreenState();
}

class _GeminiSettingsScreenState extends State<GeminiSettingsScreen> {
  final TextEditingController _keyCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  late GeminiPersona _persona;
  late GeminiVoiceName _voice;
  late bool _playWithBuddy;

  @override
  void initState() {
    super.initState();
    _persona = widget.geminiService.persona;
    _voice = widget.geminiService.voiceName;
    _playWithBuddy = widget.geminiService.playWithBuddyEnabled;
    _nameCtrl.text = widget.geminiService.companionDisplayName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Buddy & Voice Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Master Play-with-Assistant / Buddy Switch
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.activeCyan.withValues(alpha: 0.18),
                  AppColors.royalGold.withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _playWithBuddy ? AppColors.activeCyan : AppColors.darkBorder,
                width: 1.5,
              ),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Play with Assistant / Buddy',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              subtitle: const Text(
                'ON karne par (aur Gemini Key lagi hone par) aapka AI Buddy online match mein khud khelega aur gupshup karega. OFF par normal player/bot khelega.',
                style: TextStyle(fontSize: 12),
              ),
              value: _playWithBuddy,
              activeThumbColor: AppColors.activeCyan,
              onChanged: (v) async {
                setState(() => _playWithBuddy = v);
                await widget.geminiService.setPlayWithBuddySwitch(v);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Custom Buddy Name
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Assistant / Buddy Ka Naam Rakhein (e.g. Maya, Zara, Sherry)',
              prefixIcon: const Icon(Icons.badge, color: AppColors.royalGold),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 14),

          // Gemini API Key
          TextField(
            controller: _keyCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: widget.geminiService.hasApiKey
                  ? 'Gemini API Key Saved (Enter new key to update)'
                  : 'Paste Your Gemini API Key (Online Mode Only)',
              prefixIcon: const Icon(Icons.vpn_key, color: AppColors.activeCyan),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 14),

          // Gupshup & Personality Style
          DropdownButtonFormField<GeminiPersona>(
            initialValue: _persona,
            decoration: InputDecoration(
              labelText: 'Gupshup & Mood Style',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            items: const [
              DropdownMenuItem(
                value: GeminiPersona.friendYaar,
                child: Text('Best Friend / Desi Yaar (Punjabi & Urdu Gupshup)'),
              ),
              DropdownMenuItem(
                value: GeminiPersona.gfRomantic,
                child: Text('GF / Romantic & Flirty Companion'),
              ),
              DropdownMenuItem(
                value: GeminiPersona.boldAdultBanter,
                child: Text('Bold / Adult Humor & Spicy Gupshup (Safe Bounds)'),
              ),
              DropdownMenuItem(
                value: GeminiPersona.ustaadCoach,
                child: Text('Pro Kuti Ustaad (Strategy & Tips)'),
              ),
              DropdownMenuItem(
                value: GeminiPersona.roastComedy,
                child: Text('Savage Comedy & Roast Mode'),
              ),
            ],
            onChanged: (v) => setState(() => _persona = v ?? GeminiPersona.friendYaar),
          ),
          const SizedBox(height: 14),

          // Male / Female Native Voices
          DropdownButtonFormField<GeminiVoiceName>(
            initialValue: _voice,
            decoration: InputDecoration(
              labelText: 'Voice Selection (Female / Male)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            items: const [
              DropdownMenuItem(value: GeminiVoiceName.aoede, child: Text('Female - Aoede (Warm & Expressive)')),
              DropdownMenuItem(value: GeminiVoiceName.kore, child: Text('Female - Kore (Energetic & Playful)')),
              DropdownMenuItem(value: GeminiVoiceName.leda, child: Text('Female - Leda (Soft & Sweet)')),
              DropdownMenuItem(value: GeminiVoiceName.zephyr, child: Text('Female - Zephyr (Bright)')),
              DropdownMenuItem(value: GeminiVoiceName.puck, child: Text('Male - Puck (Witty & Street-Smart)')),
              DropdownMenuItem(value: GeminiVoiceName.fenrir, child: Text('Male - Fenrir (Deep & Bold)')),
              DropdownMenuItem(value: GeminiVoiceName.charon, child: Text('Male - Charon (Calm)')),
              DropdownMenuItem(value: GeminiVoiceName.orus, child: Text('Male - Orus (Friendly)')),
            ],
            onChanged: (v) => setState(() => _voice = v ?? GeminiVoiceName.aoede),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle),
              label: const Text('Save Buddy Settings'),
              onPressed: () async {
                if (_keyCtrl.text.trim().isNotEmpty) {
                  await widget.geminiService.saveApiKey(_keyCtrl.text);
                }
                await widget.geminiService.setPlayWithBuddySwitch(_playWithBuddy);
                await widget.geminiService.updatePersona(_persona, _voice, _nameCtrl.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${_nameCtrl.text.trim().isEmpty ? "Maya" : _nameCtrl.text.trim()} saved! Play with Buddy: ${_playWithBuddy ? "ON" : "OFF"}',
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
