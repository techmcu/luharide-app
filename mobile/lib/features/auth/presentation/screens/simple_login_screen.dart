import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../providers/app_language_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/app_navigator.dart';
import '../../../../features/home/presentation/screens/home_screen.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/feedback/app_feedback.dart';
import 'forgot_password_screen.dart';
import 'simple_signup_screen.dart';
import '../view_models/simple_login_view_model.dart';

class SimpleLoginScreen extends StatefulWidget {
  const SimpleLoginScreen({super.key});

  @override
  State<SimpleLoginScreen> createState() => _SimpleLoginScreenState();
}

class _SimpleLoginScreenState extends State<SimpleLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final SimpleLoginViewModel _viewModel = SimpleLoginViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_viewModel.isLoading) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _viewModel.setLoading(true);

    final authProvider = context.read<AuthProvider>();
    
    final success = await authProvider.simpleLogin(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    _viewModel.setLoading(false);

    if (success) {
      // Force navigate to HomeScreen, clear all previous routes
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false, // Remove all previous routes
        );
      }
    } else if (mounted) {
      final loc = AppLocalizations.of(context);
      final err = authProvider.error ?? loc.t('auth.login.failed_fallback');
      final isInvalidCreds = err.toLowerCase().contains('invalid') || err.toLowerCase().contains('password');
      final is404 = err.contains('404') || err.contains('nahi mila');
      AppFeedback.show(
        context,
        isInvalidCreds
            ? loc.t('auth.login.invalid_credentials')
            : (is404
                ? '$err${kDebugMode ? '\n\nAPI: ${EnvConfig.apiBaseUrl}' : ''}'
                : err),
        kind: AppFeedbackKind.error,
        duration: Duration(seconds: is404 ? 8 : 4),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguageProvider>();
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return _buildScaffold(context);
      },
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final topPadding = MediaQuery.of(context).padding.top;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = 24.0;
    final spacing = isSmallScreen ? 16.0 : 24.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isDark ? const Color(0xFF0B1220) : Colors.blue.shade50,
              isDark ? const Color(0xFF0F172A) : Colors.white,
              isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: screenHeight - topPadding - MediaQuery.of(context).padding.bottom,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: isSmallScreen ? 28 : 44),
                    Center(
                      child: Text(
                        loc.t('auth.login.title'),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 26 : 30,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.blue.shade900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing * 1.5),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: loc.t('input.email.label'),
                        hintText: loc.t('input.email.placeholder'),
                        prefixIcon: Icon(Icons.email_outlined, color: Colors.blue.shade700, size: 22),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.blue.shade600, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return loc.t('auth.login.email_required');
                        if (!value.contains('@')) return loc.t('auth.login.email_invalid');
                        return null;
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _viewModel.obscurePassword,
                      decoration: InputDecoration(
                        labelText: loc.t('auth.login.password_label'),
                        hintText: loc.t('auth.login.password_hint'),
                        prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.blue.shade700, size: 22),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _viewModel.obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () => _viewModel.toggleObscurePassword(),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.blue.shade600, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return loc.t('auth.login.password_required');
                        return null;
                      },
                    ),
                    SizedBox(height: spacing / 2),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          loc.t('auth.login.forgot_password'),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: spacing),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _viewModel.isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: Colors.blue.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _viewModel.isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                loc.t('auth.login.title'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: spacing),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SimpleSignupScreen(),
                            ),
                          );
                        },
                        child: Text(
                          loc.t('auth.login.signup_prompt'),
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_rounded, size: 20, color: Colors.grey.shade600),
                        label: Text(
                          loc.t('auth.login.back'),
                          style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
