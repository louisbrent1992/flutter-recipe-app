import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : lightSuccessColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _signInWithEmailAndPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final user = await authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted && user != null) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else if (mounted && authService.error != null) {
        _showSnackBar(authService.error!, isError: true);
        _passwordController.clear();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('An unexpected error occurred.', isError: true);
        _passwordController.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final user = await authService.signInWithGoogle();
      if (mounted && user != null) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else if (mounted && authService.error != null) {
        _showSnackBar(authService.error!, isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to sign in with Google.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final user = await authService.signInWithApple();
      if (mounted && user != null) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else if (mounted && authService.error != null) {
        _showSnackBar(authService.error!, isError: true);
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (mounted && e.code != AuthorizationErrorCode.canceled) {
        _showSnackBar('Apple sign-in failed.', isError: true);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showSnackBar('Apple sign-in failed: ${e.message}', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to sign in with Apple.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Reset Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter your email to receive a reset link.'),
                const SizedBox(height: 16),
                CupertinoTextField(
                  controller: resetEmailController,
                  placeholder: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  placeholderStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final email = resetEmailController.text.trim();
                  if (email.isNotEmpty && email.contains('@')) {
                    final authService = context.read<AuthService>();
                    final success = await authService.sendPasswordResetEmail(
                      email,
                    );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    if (mounted) {
                      _showSnackBar(
                        success
                            ? 'Reset email sent!'
                            : authService.error ?? 'Failed to send email.',
                        isError: !success,
                      );
                    }
                  }
                },
                child: const Text('Send'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Welcome Back!',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    CupertinoTextField(
                      controller: _emailController,
                      placeholder: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      placeholderStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 16),

                    CupertinoTextField(
                      controller: _passwordController,
                      placeholder: 'Password',
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _signInWithEmailAndPassword(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      placeholderStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      suffix: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                          child: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    const SizedBox(height: 8),

                    ElevatedButton(
                      onPressed:
                          _isLoading ? null : _signInWithEmailAndPassword,
                      child:
                          _isLoading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Sign In'),
                    ),
                    const SizedBox(height: 24),

                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('OR'),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24),

                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      icon: Image.network(
                        'https://www.google.com/favicon.ico',
                        height: 20,
                        width: 20,
                        errorBuilder:
                            (_, __, ___) =>
                                const Icon(Icons.g_mobiledata, size: 20),
                      ),
                      label: const Text('Sign in with Google'),
                    ),

                    if (isIOS) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _signInWithApple,
                        icon: const Icon(Icons.apple, size: 24),
                        label: const Text('Sign in with Apple'),
                      ),
                    ],
                    const SizedBox(height: 32),

                    TextButton(
                      onPressed:
                          () => Navigator.pushNamed(context, '/register'),
                      child: const Text('Don\'t have an account? Sign up'),
                    ),
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
