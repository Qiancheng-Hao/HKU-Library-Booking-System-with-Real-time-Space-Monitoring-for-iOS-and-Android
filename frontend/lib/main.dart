import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/library_list_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/ai_agent_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/ai_session_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AiSessionProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (auth.isLoggedIn) {
            return const SettingsPage();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int currentIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title: Image.asset(
          'assets/imgs/hku_logo.png',
          fit: BoxFit.contain,
          height: 45,
        ),
        centerTitle: true,
      ),

      bottomNavigationBar: NavigationBar(
        height: 56,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home, size: 40),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble, size: 40),
            label: 'Booking',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_rounded, size: 40),
            label: 'Libraries',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_sharp, size: 40),
            label: 'Settings',
          ),
        ],
        selectedIndex: currentIndex,
        onDestinationSelected: (int value) {
          // Handle destination selection
          setState(() {
            currentIndex = value;
          });
        },
      ),
      body: currentIndex == 0
          ? const HomeScreen()
          : currentIndex == 1
          ? const AiAgentScreen()
          : currentIndex == 2
          ? const LibraryListScreen()
          : currentIndex == 3
          ? const SettingsScreen()
          : Center(child: Text('Page ${currentIndex + 1}')),
    );
  }
}
