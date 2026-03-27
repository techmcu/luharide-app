import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/app_navigator.dart';
import '../../core/localization/app_localizations.dart';
import '../home/home_screen.dart';
import 'simple_login_screen.dart';

class SimpleSignupScreen extends StatefulWidget {
  final String userType;

  const SimpleSignupScreen({
    super.key,
    this.userType = 'passenger',
  });

  @override
  State<SimpleSignupScreen> createState() => _SimpleSignupScreenState();
}

class _SimpleSignupScreenState extends State<SimpleSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  int _step = 1; // 1 = enter email & send OTP, 2 = enter OTP + name + password

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.sendOTPByEmail(email, purpose: 'registration');
    setState(() => _isLoading = false);

    if (success && mounted) {
      setState(() => _step = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent to your email. Check inbox or spam.'), backgroundColor: Colors.green),
      );
    } else if (mounted) {
      final err = authProvider.error ?? 'Failed to send OTP';
      final isAlreadyRegistered = err.toLowerCase().contains('already registered');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.red,
          action: isAlreadyRegistered
              ? SnackBarAction(
                  label: 'Login',
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const SimpleLoginScreen()),
                    );
                  },
                )
              : null,
        ),
      );
    }
  }

  Future<void> _verifyAndSignup() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text;

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter 6-digit OTP'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifyOTPByEmail(
      email: email,
      otp: otp,
      name: name,
      password: password,
      role: widget.userType,
    );
    setState(() => _isLoading = false);

    if (success && mounted) {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Verification failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: _step == 1 ? _buildStep1() : _buildStep2(),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 20),
        Text(
          'Step 1 of 2',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blue[700]),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your email',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'We’ll send a 6-digit OTP. In the next step you’ll enter OTP, your name, and set a password to login later.',
          style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.4),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: t.t('input.email.label'),
            hintText: t.t('input.email.placeholder'),
            prefixIcon: const Icon(Icons.email),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Email is required';
            if (!v.contains('@') || !v.contains('.')) return 'Enter valid email';
            return null;
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Send OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Already have an account? Login', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          IconButton(
            onPressed: () => setState(() => _step = 1),
            icon: const Icon(Icons.arrow_back),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 20),
          Text(
            'Step 2 of 2',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blue[700]),
          ),
          const SizedBox(height: 8),
          const Text(
            'Verify OTP, add name & set password',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'OTP sent to ${_emailController.text.trim()}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'Enter 6-digit OTP',
              hintText: '123456',
              prefixIcon: const Icon(Icons.sms_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              counterText: '',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Your name',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[800]),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Full Name',
              hintText: 'John Doe',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Name is required';
              if (v.trim().length < 2) return 'Name must be at least 2 characters';
              return null;
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Set your password',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[800]),
          ),
          const SizedBox(height: 4),
          Text(
            'You’ll use this to login with email + password next time.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Create password (min 6 characters)',
              hintText: 'Enter password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyAndSignup,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Verify & Sign Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Already have an account? Login', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
