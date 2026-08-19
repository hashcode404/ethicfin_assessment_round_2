import 'package:ethicfin_assessment_round_2/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'data/local/database_helper.dart';
import 'presentation/providers/firebase_providers.dart';
import 'presentation/providers/auth_providers.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/task_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite database eagerly to avoid delays during UI loading
  try {
    await DatabaseHelper.instance.database;
  } catch (e) {
    debugPrint('Database initialization error: $e');
  }

  // Attempt to initialize Firebase. If config files are missing (e.g. google-services.json),
  // we catch the error gracefully and fall back to local-only offline mode.
  bool firebaseAvailable = false;
  NotificationService? notificationService;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseAvailable = true;

    // Eagerly initialize notification service
    notificationService = NotificationService();
    await notificationService.initialize();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e. Operating in local-only offline mode.');
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseAvailableProvider.overrideWithValue(firebaseAvailable),
        if (notificationService != null)
          notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Task Space',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseAvailable = ref.watch(firebaseAvailableProvider);
    if (!firebaseAvailable) {
      return const TaskListScreen();
    }

    final authState = ref.watch(authStateProvider);
    final guestMode = ref.watch(guestModeProvider);

    return authState.when(
      data: (user) {
        if (user != null || guestMode) {
          return const TaskListScreen();
        }
        return const LoginScreen();
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Text('Auth error: $error'),
        ),
      ),
    );
  }
}
