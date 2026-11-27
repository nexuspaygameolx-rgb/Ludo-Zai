import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/remote_config_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/home_lobby_screen.dart';
import 'services/community_rules_service.dart';
import 'services/gemini_agent_service.dart';
import 'services/local_progress_service.dart';
import 'services/offline_p2p_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env.example');

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  if (supabaseUrl.startsWith('http') && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  final remoteConfig = RemoteConfigService();
  await remoteConfig.fetchFromBackend();

  final localProgress = LocalProgressService();
  await localProgress.loadFromDevice();
  await localProgress.syncDeviceProgressToCloudIfNeeded();

  final communityRulesService = CommunityRulesService();
  await communityRulesService.initializeAndSync();

  final geminiService = GeminiAgentService();
  await geminiService.loadSavedSettings();

  final p2pService = OfflineP2PService();

  runApp(LudoZaiApp(
    remoteConfig: remoteConfig,
    localProgress: localProgress,
    communityRulesService: communityRulesService,
    geminiService: geminiService,
    p2pService: p2pService,
  ));
}

class LudoZaiApp extends StatelessWidget {
  final RemoteConfigService remoteConfig;
  final LocalProgressService localProgress;
  final CommunityRulesService communityRulesService;
  final GeminiAgentService geminiService;
  final OfflineP2PService p2pService;

  const LudoZaiApp({
    super.key,
    required this.remoteConfig,
    required this.localProgress,
    required this.communityRulesService,
    required this.geminiService,
    required this.p2pService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ludo-Z! 3D Desi Kuti',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      home: HomeLobbyScreen(
        remoteConfig: remoteConfig,
        localProgress: localProgress,
        communityRulesService: communityRulesService,
        p2pService: p2pService,
        geminiService: geminiService,
      ),
    );
  }
}
