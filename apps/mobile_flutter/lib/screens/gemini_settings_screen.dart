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

  @override
  void initState() {
    super.initState();
    _persona = widget.geminiService.persona;
    _voice = widget.geminiService.voiceName;
    _nameCtrl.text = widget.geminiService.companionDisplayName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maya-Style Gemini AI (Online Only)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.activeCyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.activeCyan.withValues(alpha: 0.5)),
            ),
            child: const Text(
              'Apni Gemini API Key lagane ke baad Gemini sirf Online Mode mein aapse real voice & text gupshup bhi karegi aur aapke khilaf ya 2v2 Jodi partner ban kar khud game bhi khelegi!',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keyCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: widget.geminiService.hasApiKey
                  ? 'Gemini API Key Saved (Enter new key to replace)'
                  : 'Paste Your Gemini API Key',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'AI Companion Name (e.g. Maya, Zara, Ustaad)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<GeminiPersona>(
            initialValue: _persona,
            decoration: const InputDecoration(labelText: 'Relationship & Gupshup Mode', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: GeminiPersona.friendYaar, child: Text('Friend / Desi Yaar (Punjabi & Urdu Gupshup)')),
              DropdownMenuItem(value: GeminiPersona.gfRomantic, child: Text('GF / Caring Companion Mode')),
              DropdownMenuItem(value: GeminiPersona.ustaadCoach, child: Text('Ustaad / Pro Kuti Coach')),
              DropdownMenuItem(value: GeminiPersona.roastComedy, child: Text('Comedy / Roast Mode')),
            ],
            onChanged: (v) => setState(() => _persona = v ?? GeminiPersona.friendYaar),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<GeminiVoiceName>(
            initialValue: _voice,
            decoration: const InputDecoration(labelText: 'Gemini Voice (Male / Female)', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: GeminiVoiceName.aoede, child: Text('Female - Aoede (Warm & Expressive)')),
              DropdownMenuItem(value: GeminiVoiceName.kore, child: Text('Female - Kore (Energetic)')),
              DropdownMenuItem(value: GeminiVoiceName.leda, child: Text('Female - Leda (Soft)')),
              DropdownMenuItem(value: GeminiVoiceName.zephyr, child: Text('Female - Zephyr (Bright)')),
              DropdownMenuItem(value: GeminiVoiceName.puck, child: Text('Male - Puck (Witty & Playful)')),
              DropdownMenuItem(value: GeminiVoiceName.fenrir, child: Text('Male - Fenrir (Deep)')),
              DropdownMenuItem(value: GeminiVoiceName.charon, child: Text('Male - Charon (Calm)')),
              DropdownMenuItem(value: GeminiVoiceName.orus, child: Text('Male - Orus (Friendly)')),
            ],
            onChanged: (v) => setState(() => _voice = v ?? GeminiVoiceName.aoede),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save Key & Activate Gemini Player'),
            onPressed: () async {
              if (_keyCtrl.text.trim().isNotEmpty) {
                await widget.geminiService.saveApiKey(_keyCtrl.text);
              }
              widget.geminiService.updatePersona(_persona, _voice, _nameCtrl.text);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
