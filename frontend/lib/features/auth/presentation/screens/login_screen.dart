import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/http_api_client.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../theme/app_theme.dart';
import '../controllers/login_controller.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LoginController>(
      create: (context) =>
          LoginController(authProvider: context.read<AuthProvider>()),
      child: const _LoginScreenView(),
    );
  }
}

class _LoginScreenView extends StatefulWidget {
  const _LoginScreenView();

  @override
  State<_LoginScreenView> createState() => _LoginScreenViewState();
}

class _LoginScreenViewState extends State<_LoginScreenView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await context.read<LoginController>().login(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException
          ? e.message
          : 'Network error. Please check your connection.';
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = context.watch<LoginController>();

    final gradientColors = isDark
        ? const [Color(0xFF0A1520), AppColors.deepNavy, Color(0xFF1C2E48)]
        : [
            const Color(0xFFEDF5F1),
            AppColors.hkuGreen.withValues(alpha: 0.12),
            Colors.white,
          ];
    final headlineColor = isDark ? Colors.white : cs.onSurface;
    final accentColor = isDark ? AppColors.cyberCyan : AppColors.hkuGreen;

    return Scaffold(
      backgroundColor: gradientColors.first,
      body: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: size.height),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 80,
              left: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.hkuGreen.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: size.height),
                child: Column(
                  children: [
                    SafeArea(
                      bottom: false,
                      child: SizedBox(
                        height: size.height * 0.30,
                        child: Column(
                          children: [
                            const SizedBox(height: AppSpacing.lg),
                            Image.asset(
                              isDark
                                  ? 'assets/imgs/hku_logo_transparent_gray_1.png'
                                  : 'assets/imgs/hku_logo_transparent_back.png',
                              height: 44,
                              fit: BoxFit.contain,
                            ),
                            const Spacer(),
                            Text(
                              'Welcome Back',
                              style: tt.headlineMedium?.copyWith(
                                color: headlineColor,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.09),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.30),
                                ),
                              ),
                              child: Text(
                                'HKU Library Booking',
                                style: tt.bodySmall?.copyWith(
                                  color: accentColor,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.xl,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sign In',
                              style: tt.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: headlineColor,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            RawAutocomplete<String>(
                              textEditingController: _emailController,
                              focusNode: _emailFocusNode,
                              optionsBuilder: (textEditingValue) {
                                final text = textEditingValue.text;
                                if (!text.contains('@')) {
                                  return const Iterable<String>.empty();
                                }
                                final parts = text.split('@');
                                if (parts.length > 2) {
                                  return const Iterable<String>.empty();
                                }
                                final prefix = parts[0];
                                final domainPart = parts.length == 2
                                    ? parts[1]
                                    : '';
                                const domains = ['hku.hk', 'connect.hku.hk'];
                                return domains
                                    .where((d) => d.startsWith(domainPart))
                                    .map((d) => '$prefix@$d');
                              },
                              fieldViewBuilder:
                                  (
                                    context,
                                    textEditingController,
                                    focusNode,
                                    onFieldSubmitted,
                                  ) {
                                    return TextFormField(
                                      controller: textEditingController,
                                      focusNode: focusNode,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: InputDecoration(
                                        labelText: 'HKU Email',
                                        prefixIcon: Icon(
                                          Icons.email_outlined,
                                          color: cs.primary,
                                        ),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return 'Required';
                                        }
                                        if (!v.contains('@') ||
                                            !v.contains('.')) {
                                          return 'Enter a valid email';
                                        }
                                        return null;
                                      },
                                      onFieldSubmitted: (_) =>
                                          onFieldSubmitted(),
                                    );
                                  },
                              optionsViewBuilder:
                                  (context, onSelected, options) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 4,
                                        color: cs.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.md,
                                        ),
                                        child: SizedBox(
                                          width:
                                              MediaQuery.of(
                                                context,
                                              ).size.width -
                                              48,
                                          child: ListView.builder(
                                            padding: EdgeInsets.zero,
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            itemBuilder: (context, index) {
                                              final option = options.elementAt(
                                                index,
                                              );
                                              return ListTile(
                                                title: Text(option),
                                                onTap: () => onSelected(option),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: cs.primary,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                              onFieldSubmitted: (_) => _login(),
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            controller.isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : ElevatedButton(
                                    onPressed: _login,
                                    child: const Text('Sign In'),
                                  ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
