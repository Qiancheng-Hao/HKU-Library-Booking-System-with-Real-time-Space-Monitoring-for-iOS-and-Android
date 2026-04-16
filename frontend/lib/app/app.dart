import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth/auth_session.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import 'app_providers.dart';
import 'root_shell.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppProviders(child: _AppView());
  }
}

class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  bool _handlerRegistered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_handlerRegistered) {
      _handlerRegistered = true;
      final auth = context.read<AuthProvider>();
      AuthSession.registerUnauthorizedHandler(() {
        auth.logout();
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, AuthProvider>(
      builder: (context, themeProvider, auth, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'HKU Library',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeProvider.themeMode,
          home: auth.isLoading
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : auth.isLoggedIn
              ? const RootShell()
              : const LoginScreen(),
        );
      },
    );
  }
}
