import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/library_list_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/ai_agent_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/ai_session_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AiSessionProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) => MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'HKU Library',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeProvider.themeMode,
        home: Consumer<AuthProvider>(
          builder: (context, auth, child) {
            if (auth.isLoading) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (auth.isLoggedIn) {
              return const RootShell();
            } else {
              return const LoginScreen();
            }
          },
        ),
      ),
    );
  }
}

/// Root navigation shell hosting the 4 main tabs.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _currentIndex = 0;

  static const _pages = <Widget>[
    HomeScreen(),
    AiAgentScreen(),
    LibraryListScreen(),
    SettingsScreen(),
  ];

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.auto_awesome_outlined),
      selectedIcon: Icon(Icons.auto_awesome_rounded),
      label: 'AI',
    ),
    NavigationDestination(
      icon: Icon(Icons.menu_book_outlined),
      selectedIcon: Icon(Icons.menu_book_rounded),
      label: 'Libraries',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [AppColors.deepNavy, Color(0xFF253D62)]
                      : const [Color(0xFFD6EBE4), Color(0xFFBFDDD5)],
                ),
              ),
            );
          },
        ),
        bottom: const _AdaptiveAppBarBottom(),
        title: Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Image.asset(
              isDark
                  ? 'assets/imgs/hku_logo_transparent_gray_1.png'
                  : 'assets/imgs/hku_logo_transparent_back.png',
              height: 44,
              fit: BoxFit.contain,
            );
          },
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: IndexedStack(index: _currentIndex, children: _pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        destinations: _destinations,
        onDestinationSelected: (value) => setState(() => _currentIndex = value),
      ),
    );
  }
}

class _AdaptiveAppBarBottom extends StatelessWidget
    implements PreferredSizeWidget {
  const _AdaptiveAppBarBottom();

  @override
  Size get preferredSize => const Size.fromHeight(1.5);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glowColor = isDark ? AppColors.cyberCyan : const Color(0xFF4CAF8A);

    return Container(
      height: 1.5,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            glowColor.withValues(alpha: isDark ? 0.9 : 0.6),
            Colors.transparent,
          ],
          stops: const [0.05, 0.5, 0.95],
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: isDark ? 0.35 : 0.2),
            blurRadius: isDark ? 10 : 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
