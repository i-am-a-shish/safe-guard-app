import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'core/constants.dart';
import 'providers/contacts_provider.dart';
import 'providers/protection_provider.dart';
import 'providers/settings_provider.dart';
import 'services/storage_service.dart';
import 'services/audio_processing_service.dart';
import 'services/tflite_service.dart';
import 'services/background_service.dart';
import 'services/camera_recording_service.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize core services
  await StorageService.init();
  AudioProcessingService.init();
  await BackgroundServiceManager.init();

  // Pre-load TFLite model in the main isolate so the test button works
  // immediately. The background service loads its own copy independently.
  final modelLoaded = await TfliteService.init();
  debugPrint('main: TFLite model loaded in main isolate: $modelLoaded');

  // Initialize camera service (just discovers available cameras)
  await CameraRecordingService.init();

  // Auto-start protection monitoring every time the app is opened,
  // as long as onboarding has been completed.
  if (StorageService.isOnboardingComplete()) {
    // Always set protection enabled so ProtectionProvider reflects active state
    await StorageService.setSetting(AppConstants.keyProtectionEnabled, true);
    // Start background audio monitoring (idempotent – safe to call if already running)
    await BackgroundServiceManager.startService();
  }

  runApp(const SafeGuardHerApp());
}

class SafeGuardHerApp extends StatelessWidget {
  const SafeGuardHerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ContactsProvider()),
        ChangeNotifierProvider(create: (_) => ProtectionProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: StorageService.isOnboardingComplete()
            ? const HomeScreen()
            : const OnboardingScreen(),
      ),
    );
  }
}
