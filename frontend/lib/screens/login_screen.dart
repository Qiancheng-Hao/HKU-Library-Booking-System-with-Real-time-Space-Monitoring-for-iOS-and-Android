import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'register_screen.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
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
    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthProvider>(
        context,
        listen: false,
      ).login(_emailController.text, _passwordController.text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Login Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Force dark theme so inputs/buttons render correctly on the dark background
    return Theme(
      data: AppTheme.dark(),
      child: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;

          return Scaffold(
            backgroundColor: const Color(0xFF0A1520),
            body: Container(
              width: double.infinity,
              constraints: BoxConstraints(minHeight: size.height),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0A1520),
                    AppColors.deepNavy,
                    Color(0xFF1C2E48),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Top-right cyan glow orb
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
                            AppColors.cyberCyan.withValues(alpha: 0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Bottom-left HKU green glow orb
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

                  // Scrollable content
                  SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: size.height),
                      child: Column(
                      children: [
                        // ---- Hero section ----
                        SafeArea(
                          bottom: false,
                          child: SizedBox(
                            height: size.height * 0.30,
                            child: Column(
                              children: [
                                const SizedBox(height: AppSpacing.lg),
                                // Horizontal logo (original style)
                                Image.asset(
                                  'assets/imgs/hku_logo_transparent_gray_1.png',
                                  height: 44,
                                  fit: BoxFit.contain,
                                ),
                                const Spacer(),
                                Text(
                                  'Welcome Back',
                                  style: tt.headlineMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                // HKU brand pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.lg,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.cyberCyan.withValues(alpha: 0.09),
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                    border: Border.all(
                                      color: AppColors.cyberCyan.withValues(alpha: 0.30),
                                    ),
                                  ),
                                  child: Text(
                                    'HKU Library Booking',
                                    style: tt.bodySmall?.copyWith(
                                      color: AppColors.cyberCyan.withValues(alpha: 0.88),
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

                        // ---- Form section ----
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
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xl),

                                // Email
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
                                    final domainPart = parts.length == 2 ? parts[1] : '';
                                    const domains = ['hku.hk', 'connect.hku.hk'];
                                    return domains
                                        .where((d) => d.startsWith(domainPart))
                                        .map((d) => '$prefix@$d');
                                  },
                                  fieldViewBuilder: (
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
                                      validator: (v) =>
                                          v!.isEmpty ? 'Required' : null,
                                      onFieldSubmitted: (_) => onFieldSubmitted(),
                                    );
                                  },
                                  optionsViewBuilder: (context, onSelected, options) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 4,
                                        color: cs.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                        child: SizedBox(
                                          width: MediaQuery.of(context).size.width - 48,
                                          child: ListView.builder(
                                            padding: EdgeInsets.zero,
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            itemBuilder: (context, index) {
                                              final option = options.elementAt(index);
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

                                // Password
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

                                // Login button
                                _isLoading
                                    ? const Center(child: CircularProgressIndicator())
                                    : ElevatedButton(
                                        onPressed: _login,
                                        child: const Text('Sign In'),
                                      ),
                                const SizedBox(height: AppSpacing.md),

                                // Register link
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Don't have an account? ",
                                      style: tt.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const RegisterScreen(),
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Create Account',
                                        style: tt.bodyMedium?.copyWith(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
        },
      ),
    );
  }
}
