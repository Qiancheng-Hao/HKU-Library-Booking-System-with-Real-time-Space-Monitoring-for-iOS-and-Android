import 'dart:math' as math;

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

class _LoginScreenViewState extends State<_LoginScreenView>
    with WidgetsBindingObserver {
  static const _emailDomains = ['connect.hku.hk', 'hku.hk', 'cs.hku.hk'];
  static const _emailOptionTileHeight = 56.0;
  static const _emailOptionsGap = 12.0;
  static const _maxVisibleEmailOptions = 3;

  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _emailFieldKey = GlobalKey();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _emailController.addListener(_handleEmailInputChanged);
    _emailFocusNode.addListener(_handleEmailInputChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.removeListener(_handleEmailInputChanged);
    _emailFocusNode.removeListener(_handleEmailInputChanged);
    _scrollController.dispose();
    _emailController.dispose();
    _emailFocusNode.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _scheduleEmailSuggestionScroll();
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

  List<String> _emailOptionsFor(String text) {
    if (!text.contains('@')) return const [];

    final parts = text.split('@');
    if (parts.length > 2) return const [];

    final prefix = parts[0];
    final domainPart = parts.length == 2 ? parts[1] : '';
    if (_emailDomains.contains(domainPart)) return const [];

    return _emailDomains
        .where((domain) => domain.startsWith(domainPart))
        .map((domain) => '$prefix@$domain')
        .toList(growable: false);
  }

  List<String> get _emailOptions => _emailOptionsFor(_emailController.text);

  bool get _shouldShowEmailOptions =>
      _emailFocusNode.hasFocus && _emailOptions.isNotEmpty;

  void _handleEmailInputChanged() {
    if (mounted) setState(() {});
    _scheduleEmailSuggestionScroll();
  }

  void _selectEmailOption(String option) {
    _emailController.value = TextEditingValue(
      text: option,
      selection: TextSelection.collapsed(offset: option.length),
    );
    _emailFocusNode.requestFocus();
  }

  void _scheduleEmailSuggestionScroll() {
    if (!_emailFocusNode.hasFocus) return;

    final optionCount = _emailOptionsFor(_emailController.text).length;
    if (optionCount == 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollEmailSuggestionsIntoView(optionCount);
      for (final delay in const [
        Duration(milliseconds: 120),
        Duration(milliseconds: 280),
        Duration(milliseconds: 440),
      ]) {
        Future<void>.delayed(delay, () {
          if (mounted) _scrollEmailSuggestionsIntoView(optionCount);
        });
      }
    });
  }

  void _scrollEmailSuggestionsIntoView(int optionCount) {
    if (!mounted || !_scrollController.hasClients) return;

    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardInset <= 0) return;

    final renderObject = _emailFieldKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final optionsHeight = (optionCount * _emailOptionTileHeight)
        .clamp(0.0, _emailOptionTileHeight * _maxVisibleEmailOptions)
        .toDouble();
    final fieldBottom =
        renderObject.localToGlobal(Offset.zero).dy + renderObject.size.height;
    final suggestionsBottom = _shouldShowEmailOptions
        ? fieldBottom + _emailOptionsGap + optionsHeight
        : fieldBottom;
    final availableBottom =
        MediaQuery.of(context).size.height - keyboardInset - _emailOptionsGap;
    final overflow = suggestionsBottom - availableBottom;

    if (overflow <= 0) return;

    final targetOffset =
        (_scrollController.offset + overflow + _emailOptionsGap)
            .clamp(0.0, _scrollController.position.maxScrollExtent)
            .toDouble();
    if ((targetOffset - _scrollController.offset).abs() < 1) return;

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
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
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              padding: EdgeInsets.only(bottom: keyboardInset),
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
                            KeyedSubtree(
                              key: _emailFieldKey,
                              child: TextFormField(
                                controller: _emailController,
                                focusNode: _emailFocusNode,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'HKU Email',
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                    color: cs.primary,
                                  ),
                                ),
                                onTap: _scheduleEmailSuggestionScroll,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Required';
                                  }
                                  if (!v.contains('@') || !v.contains('.')) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            if (_shouldShowEmailOptions) ...[
                              const SizedBox(height: _emailOptionsGap),
                              Material(
                                elevation: 4,
                                color: cs.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _EmailOptionsList(
                                  options: _emailOptions,
                                  maxVisibleOptions: _maxVisibleEmailOptions,
                                  itemHeight: _emailOptionTileHeight,
                                  onSelected: _selectEmailOption,
                                ),
                              ),
                            ],
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

class _EmailOptionsList extends StatefulWidget {
  const _EmailOptionsList({
    required this.options,
    required this.maxVisibleOptions,
    required this.itemHeight,
    required this.onSelected,
  });

  final List<String> options;
  final int maxVisibleOptions;
  final double itemHeight;
  final ValueChanged<String> onSelected;

  @override
  State<_EmailOptionsList> createState() => _EmailOptionsListState();
}

class _EmailOptionsListState extends State<_EmailOptionsList> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleOptionCount = math.min(
      widget.options.length,
      widget.maxVisibleOptions,
    );

    return SizedBox(
      height: widget.itemHeight * visibleOptionCount,
      child: Scrollbar(
        controller: _controller,
        interactive: true,
        thumbVisibility: widget.options.length > widget.maxVisibleOptions,
        child: ListView.builder(
          controller: _controller,
          padding: EdgeInsets.zero,
          primary: false,
          physics: const ClampingScrollPhysics(),
          itemExtent: widget.itemHeight,
          itemCount: widget.options.length,
          itemBuilder: (context, index) {
            final option = widget.options[index];
            return ListTile(
              title: Text(option),
              onTap: () => widget.onSelected(option),
            );
          },
        ),
      ),
    );
  }
}
