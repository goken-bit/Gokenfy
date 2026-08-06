import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'core/theme.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('GOKENFY CRASH: ${details.exceptionAsString()}');
  };
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.gokenfy.audio.channel',
      androidNotificationChannelName: 'Gokenfy playback',
      androidNotificationChannelDescription:
          'Keeps music playing while you use other apps.',
      androidNotificationOngoing: true,
      // Keep the foreground service alive even when paused so the system does
      // not reclaim the process while the app is in the background.
      androidStopForegroundOnPause: false,
    ).timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('GOKENFY: just_audio_background init failed: $e');
  }
  runApp(const ProviderScope(child: GokenfyApp()));
}

class GokenfyApp extends StatelessWidget {
  const GokenfyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gokenfy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      themeMode: ThemeMode.dark,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
        Locale('fr'),
        Locale('de'),
        Locale('pt'),
        Locale('hi'),
        Locale('ja'),
        Locale('zh'),
      ],
      home: const HomeShell(),
    );
  }
}
