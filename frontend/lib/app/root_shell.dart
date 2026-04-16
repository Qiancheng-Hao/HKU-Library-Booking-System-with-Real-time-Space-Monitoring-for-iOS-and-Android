import 'package:flutter/material.dart';

import '../features/ai_agent/presentation/screens/ai_agent_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/library/presentation/screens/library_list_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../theme/app_theme.dart';

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
