import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recipease/providers/auth_provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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

  String? _emailError;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
  }

  void _onEmailChanged() {
    final email = _emailController.text;
    final newError =
        email.isNotEmpty && !email.contains('@')
            ? 'Please enter a valid email'
            : null;

    // Only update if error state actually changed to prevent unnecessary rebuilds
    if (_emailError != newError) {
      setState(() {
        _emailError = newError;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    // Hide any existing snackbars
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Show new snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.surface.withValues(
                alpha: Theme.of(context).colorScheme.alphaVeryHigh,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : lightSuccessColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action:
            isError
                ? SnackBarAction(
                  label: 'Dismiss',
                  textColor: Theme.of(context).colorScheme.onError,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                )
                : null,
      ),
    );
  }

  String? _validatePassword(String? value) {
    // Only check if password is provided - Firebase handles authentication
    // Strict password validation is only enforced during registration/password change
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    return null;
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmailAndPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = context.read<AuthService>();

    try {
      final user = await authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted && user != null) {
        _showSnackBar('Successfully signed in!');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else if (mounted && authService.error != null) {
        _showSnackBar(authService.error!, isError: true);
        // Clear password field on authentication error
        _passwordController.clear();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'An unexpected error occurred. Please try again.',
          isError: true,
        );
        _passwordController.clear();
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    final authService = context.read<AuthService>();

    try {
      final user = await authService.signInWithGoogle();
      if (mounted && user != null) {
        _showSnackBar('Successfully signed in with Google!');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else if (mounted && authService.error != null) {
        _showSnackBar(authService.error!, isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Failed to sign in with Google. Please try again.',
          isError: true,
        );
      }
    }
  }

  Future<void> _signInWithApple() async {
    final authService = context.read<AuthService>();

    try {
      final user = await authService.signInWithApple();
      if (mounted && user != null) {
        _showSnackBar('Successfully signed in with Apple!');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else if (mounted && authService.error != null) {
        // Check for specific error types
        if (authService.error!.contains('invalid-credential')) {
          _showSnackBar(
            'Apple sign-in configuration error. Please contact support or try another sign-in method.',
            isError: true,
          );
        } else {
          _showSnackBar(authService.error!, isError: true);
        }
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (mounted) {
        String message;
        switch (e.code) {
          case AuthorizationErrorCode.canceled:
            message =
                'Sign in was canceled. Please try again when you\'re ready.';
            break;
          case AuthorizationErrorCode.failed:
            message = 'Sign in failed. Please try again.';
            break;
          case AuthorizationErrorCode.invalidResponse:
            message = 'Invalid response from Apple. Please try again.';
            break;
          case AuthorizationErrorCode.notHandled:
            message = 'Sign in could not be completed. Please try again.';
            break;
          case AuthorizationErrorCode.unknown:
          default:
            message = 'An unexpected error occurred. Please try again.';
        }
        _showSnackBar(message, isError: true);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message;
        if (e.code == 'invalid-credential') {
          message =
              'Apple sign-in configuration error. Please contact support or try another sign-in method.';
        } else {
          message = 'Failed to sign in with Apple: ${e.message}';
        }
        _showSnackBar(message, isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Failed to sign in with Apple. Please try again.',
          isError: true,
        );
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Reset Password',
              style: TextStyle(
                fontSize: AppTypography.responsiveHeadingSize(
                  context,
                  mobile: 20.0,
                  tablet: 22.0,
                  desktop: 24.0,
                ),
              ),
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter your email address and we\'ll send you a link to reset your password.',
                    style: TextStyle(
                      fontSize: AppTypography.responsiveFontSize(
                        context,
                        mobile: 14.0,
                        tablet: 15.0,
                        desktop: 16.0,
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.responsive(context)),
                  TextFormField(
                    controller: resetEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            contentPadding: AppSpacing.allResponsive(context),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              Consumer<AuthService>(
                builder: (context, authService, child) {
                  return ElevatedButton(
                    onPressed:
                        authService.isLoading
                            ? null
                            : () async {
                              if (formKey.currentState!.validate()) {
                                final success = await authService
                                    .sendPasswordResetEmail(
                                      resetEmailController.text.trim(),
                                    );

                                if (context.mounted) {
                                  Navigator.pop(context);

                                  if (success) {
                                    _showSnackBar(
                                      'Password reset email sent! Check your inbox.',
                                    );
                                  } else {
                                    _showSnackBar(
                                      authService.error ??
                                          'Failed to send reset email.',
                                      isError: true,
                                    );
                                  }
                                }
                              }
                            },
                    child:
                        authService.isLoading
                            ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Send Reset Link'),
                  );
                },
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              AppBreakpoints.isDesktop(context)
                  ? 32.0
                  : AppBreakpoints.isTablet(context)
                  ? 28.0
                  : 24.0,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth:
                    AppBreakpoints.isDesktop(context)
                        ? 500
                        : AppBreakpoints.isTablet(context)
                        ? 450
                        : double.infinity,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Welcome Back!',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineLarge?.copyWith(fontSize: 20),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(
                      height:
                          AppBreakpoints.isDesktop(context)
                              ? 24
                              : AppBreakpoints.isTablet(context)
                              ? 20
                              : 16,
                    ),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: const OutlineInputBorder(),
                        errorText: _emailError,
                        errorMaxLines: 1,
                        isDense: true,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed:
                          authService.isLoading
                              ? null
                              : _signInWithEmailAndPassword,
                      child:
                          authService.isLoading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Sign In'),
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed:
                          authService.isLoading ? null : _signInWithGoogle,
                      icon: Image.network(
                        'https://www.google.com/favicon.ico',
                        height:
                            AppBreakpoints.isDesktop(context)
                                ? 28
                                : AppBreakpoints.isTablet(context)
                                ? 26
                                : 24,
                      ),
                      label: const Text('Sign in with Google'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical:
                              AppBreakpoints.isDesktop(context)
                                  ? 16
                                  : AppBreakpoints.isTablet(context)
                                  ? 14
                                  : 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Apple Sign In button - only show on iOS
                    if (Theme.of(context).platform == TargetPlatform.iOS)
                      FutureBuilder<bool>(
                        future: SignInWithApple.isAvailable(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox.shrink();
                          }

                          if (snapshot.data == true) {
                            return OutlinedButton.icon(
                              onPressed:
                                  authService.isLoading
                                      ? null
                                      : _signInWithApple,
                              icon: Icon(
                                Icons.apple,
                                size:
                                    AppBreakpoints.isDesktop(context)
                                        ? 28
                                        : AppBreakpoints.isTablet(context)
                                        ? 26
                                        : 24,
                              ),
                              label: const Text('Sign in with Apple'),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical:
                                      AppBreakpoints.isDesktop(context)
                                          ? 16
                                          : AppBreakpoints.isTablet(context)
                                          ? 14
                                          : 12,
                                ),
                              ),
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
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
