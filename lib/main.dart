import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/signup_form_provider.dart';
import 'screens/auth_gate.dart';
import 'screens/home/home_page.dart';
import 'screens/login/login_screen.dart';
import 'screens/login/signup_screen.dart';
import 'screens/messages/messages_page.dart';
import 'screens/profile/profile_page.dart';
import 'services/auth_service.dart';
import 'services/court_service.dart';
import 'services/user_service.dart';
import 'theme/app_theme.dart';
import 'widgets/main_bottom_nav.dart';

/// Used by non-widget code (e.g. PushNotificationService) to push
/// routes without a BuildContext.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'rootNavigatorKey',
);

/// Used by non-widget code to show SnackBars without a BuildContext.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>(debugLabel: 'rootScaffoldMessengerKey');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Debug-only courts seed + image-repair. The `assert(...)` block
  // is stripped from release builds, so production never seeds.
  assert(() {
    final service = CourtService();
    () async {
      await service.seedCourtsIfEmpty();
      await service.repairCourtImagesIfNeeded();
    }();
    return true;
  }());

  runApp(const RallyUpApp());
}

class RallyUpApp extends StatelessWidget {
  const RallyUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<UserService>(create: (_) => UserService()),
        ChangeNotifierProvider<AuthProvider>(
          create: (ctx) => AuthProvider(
            authService: ctx.read<AuthService>(),
            userService: ctx.read<UserService>(),
          ),
        ),
        ChangeNotifierProvider<SignupFormProvider>(
          create: (_) => SignupFormProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'RallyUp',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        navigatorKey: rootNavigatorKey,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        home: const AuthGate(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
        },
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final int initialIndex;

  /// App-wide key so any widget can switch tabs without destroying
  /// the shell (which would also pop AuthGate off the stack).
  static final GlobalKey<MainShellState> globalKey =
      GlobalKey<MainShellState>();

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  late int _currentIndex;

  final List<Widget> _pages = const [HomePage(), MessagesPage(), ProfilePage()];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  /// Entry point for tab-switching from outside MainShell.
  void switchTo(int index) {
    if (index < 0 || index >= _pages.length) return;
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = widget.initialIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    // During the frame between signOut/delete clearing the provider
    // and AuthGate's rebuild, render nothing — otherwise the shell's
    // white Scaffold flashes as a blank page.
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: MainBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}
