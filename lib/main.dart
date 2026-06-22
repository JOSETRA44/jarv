import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'infrastructure/notifications/local_notification_service.dart';
import 'presentation/providers/app_lifecycle_provider.dart';
import 'presentation/providers/notification_coordinator.dart';
import 'presentation/providers/poltergeist_provider.dart';
import 'presentation/providers/terminal_provider.dart';
import 'presentation/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize the notification plugin early (channels, tap handling).
  await LocalNotificationService.instance.init();

  runApp(
    const ProviderScope(
      child: JarvisApp(),
    ),
  );
}

class JarvisApp extends ConsumerStatefulWidget {
  const JarvisApp({super.key});

  @override
  ConsumerState<JarvisApp> createState() => _JarvisAppState();
}

class _JarvisAppState extends ConsumerState<JarvisApp>
    with WidgetsBindingObserver {
  Timer? _resumeDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Instantiate the notification coordinator so it starts listening.
    ref.read(notificationCoordinatorProvider);
  }

  @override
  void dispose() {
    _resumeDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appLifecycleProvider.notifier).state = state;
    if (state == AppLifecycleState.resumed) {
      // Debounce: Android can fire several resumed transitions in a row.
      // Collapsing them avoids redundant reconnect passes. The shared
      // AuthService single-flights the login, so even a missed debounce
      // can't produce duplicate POST /api/auth/login bursts.
      _resumeDebounce?.cancel();
      _resumeDebounce = Timer(const Duration(milliseconds: 500), () {
        ref.read(terminalProvider.notifier).onResume();
        // Stagger the second module so the two WS handshakes don't race.
        Future.delayed(const Duration(milliseconds: 300), () {
          ref.read(poltergeistProvider.notifier).onResume();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'JARVIS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
