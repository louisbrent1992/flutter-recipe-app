import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';
import '../../providers/user_profile_provider.dart'; // ADDED IMPORT

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  // New state variables to store redirect arguments from SplashScreen
  String? _redirectRoute;
  String? _redirectUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if arguments were passed (e.g., from SplashScreen for import redirect)
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map) {
      _redirectRoute = args['redirectRoute'] as String?;
      _redirectUrl = args['url'] as String?;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Helper method to handle post-login navigation based on redirect arguments
  // CHANGED: Made async and added profile load
  Future<void> _handlePostSignInNavigation() async {
    if (!mounted) return;

    // --- CRITICAL FIX: AWAIT PROFILE LOAD TO ENSURE CREDITS ARE READY ---
    // 1. Get the provider for profile data (credits)
    final userProfileProvider = context.read<UserProfileProvider>();

    // 2. Explicitly await profile load. Use a try-catch, but don't block navigation
    //    if the server is slow or fails (though successful login usually ensures profile exists).
    try {
      await userProfileProvider.loadProfile();
    } catch (e) {
      debugPrint(
        'Warning: Failed to load user profile/credits immediately after login: $e',
      );
    }

    if (!mounted) return;
    // ---------------------------------------------------------------------
    // 3. Handle redirect navigation
    if (_redirectRoute == '/import' && _redirectUrl != null) {
      // Clear navigation history and push to the intended import screen
      Navigator.pushNamedAndRemoveUntil(
        context,
        _redirectRoute!,
        (route) => false,
        arguments: _redirectUrl,
      );
    } else {
      // Default behavior
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  /// Converts Firebase Auth error codes to user-friendly messages
  String _getPhoneAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Please enter a valid phone number with country code (e.g., +1 for US).';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'Phone sign-in is not enabled. Please contact support.';
      case 'invalid-verification-code':
        return 'The verification code is incorrect. Please try again.';
      case 'invalid-verification-id':
        return 'Verification session expired. Please request a new code.';
      case 'session-expired':
        return 'The verification code has expired. Please request a new code.';
      case 'credential-already-in-use':
        return 'This phone number is already linked to another account.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'app-not-authorized':
        return 'This app is not authorized for phone authentication.';
      case 'captcha-check-failed':
        return 'Security verification failed. Please try again.';
      case 'missing-phone-number':
        return 'Please enter your phone number.';
      default:
        // Check if the message contains common error patterns
        final message = e.message?.toLowerCase() ?? '';
        if (message.contains('invalid format') || message.contains('e.164')) {
          return 'Please enter a valid phone number with country code (e.g., +1 555 555 5555).';
        }
        if (message.contains('too_short')) {
          return 'Phone number is too short. Please include area code (e.g., +1 555 555 5555).';
        }
        if (message.contains('region') ||
            message.contains('sms unable to be sent')) {
          return 'SMS verification is not available for your region. Please try another sign-in method.';
        }
        if (message.contains('blocked') ||
            message.contains('unusual activity')) {
          return 'This device has been blocked due to unusual activity. Try again later.';
        }
        if (message.contains('network')) {
          return 'Network error. Please check your connection and try again.';
        }
        return 'Unable to verify phone number. Please try again.';
    }
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
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar('Please enter a valid email', isError: true);
      return;
    }

    if (password.isEmpty) {
      _showSnackBar('Please enter your password', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final user = await authService.signInWithEmailAndPassword(
        email,
        password,
      );

      if (mounted && user != null) {
        // AWAIT the new async handler to ensure profile/credits are loaded
        await _handlePostSignInNavigation();
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
        // AWAIT the new async handler
        await _handlePostSignInNavigation();
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
        // AWAIT the new async handler
        await _handlePostSignInNavigation();
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

  Future<void> _signInWithFacebook() async {
    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final user = await authService.signInWithFacebook();
      if (mounted && user != null) {
        // AWAIT the new async handler
        await _handlePostSignInNavigation();
      } else if (mounted && authService.error != null) {
        _showSnackBar(authService.error!, isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to sign in with Facebook.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithYahoo() async {
    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final user = await authService.signInWithYahoo();
      if (mounted && user != null) {
        // AWAIT the new async handler
        await _handlePostSignInNavigation();
      } else if (mounted && authService.error != null) {
        _showSnackBar(authService.error!, isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to sign in with Yahoo.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showPhoneSignInDialog() {
    final phoneController = TextEditingController();
    final codeController = TextEditingController();
    String? verificationId;
    bool codeSent = false;
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  codeSent ? 'Enter Verification Code' : 'Enter Phone Number',
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (!codeSent) ...[
                      CupertinoTextField(
                        controller: phoneController,
                        placeholder: '+1 555 555 5555',
                        placeholderStyle: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        keyboardType: TextInputType.phone,
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
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Include country code (e.g., +1 for US)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ] else
                      CupertinoTextField(
                        controller: codeController,
                        placeholder: 'SMS Code',
                        placeholderStyle: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        keyboardType: TextInputType.number,
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
                      ),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
                actions: [
                  if (!isLoading)
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  if (!isLoading)
                    ElevatedButton(
                      onPressed: () async {
                        final authService = context.read<AuthService>();

                        setDialogState(() {
                          isLoading = true;
                          errorText = null;
                        });

                        if (!codeSent) {
                          // Send Code
                          var phone = phoneController.text.trim();
                          if (phone.isEmpty) {
                            setDialogState(() {
                              isLoading = false;
                              errorText = "Please enter a phone number";
                            });
                            return;
                          }

                          // Auto-add + if missing and looks like it has country code
                          if (!phone.startsWith('+')) {
                            phone = '+$phone';
                          }
                          // Remove any spaces, dashes, or parentheses for E.164 format
                          phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

                          await authService.verifyPhoneNumber(
                            phoneNumber: phone,
                            onCodeSent: (verId) {
                              if (context.mounted) {
                                setDialogState(() {
                                  verificationId = verId;
                                  codeSent = true;
                                  isLoading = false;
                                });
                              }
                            },
                            onVerificationFailed: (e) {
                              if (context.mounted) {
                                setDialogState(() {
                                  isLoading = false;
                                  errorText = _getPhoneAuthErrorMessage(e);
                                });
                              }
                            },
                            onVerificationCompleted: (credential) async {
                              // Auto verification (Android)
                              if (context.mounted) {
                                Navigator.pop(context); // Close dialog
                                // AWAIT the new async handler
                                await _handlePostSignInNavigation();
                              }
                            },
                            onCodeAutoRetrievalTimeout: (verId) {
                              verificationId = verId;
                            },
                          );
                        } else {
                          // Verify Code
                          final code = codeController.text.trim();
                          if (code.isEmpty) {
                            setDialogState(() {
                              isLoading = false;
                              errorText = "Please enter the code";
                            });
                            return;
                          }

                          if (verificationId != null) {
                            final user = await authService
                                .signInWithPhoneCredential(
                                  verificationId!,
                                  code,
                                );
                            if (user != null && context.mounted) {
                              Navigator.pop(context);
                              // AWAIT the new async handler
                              await _handlePostSignInNavigation();
                            } else if (context.mounted) {
                              String friendlyError =
                                  'The verification code is incorrect. Please try again.';
                              final error =
                                  authService.error?.toLowerCase() ?? '';
                              if (error.contains('expired') ||
                                  error.contains('session')) {
                                friendlyError =
                                    'The verification code has expired. Please request a new code.';
                              } else if (error.contains('invalid')) {
                                friendlyError =
                                    'The verification code is incorrect. Please try again.';
                              }
                              setDialogState(() {
                                isLoading = false;
                                errorText = friendlyError;
                              });
                            }
                          }
                        }
                      },
                      child: Text(codeSent ? 'Verify' : 'Send Code'),
                    ),
                ],
              );
            },
          ),
    );
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();

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
                  placeholderStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  keyboardType: TextInputType.emailAddress,
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
                  if (email.isEmpty || !email.contains('@')) {
                    // Show error somehow or just return
                    return;
                  }

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

    return SafeArea(
      child: Scaffold(
        backgroundColor:
            Colors.transparent, // Let global background show through
        extendBody: true,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
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
                    placeholderStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
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
                  ),
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: _passwordController,
                    placeholder: 'Password',
                    placeholderStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
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
                    suffix: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
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
                    onSubmitted: (_) => _signInWithEmailAndPassword(),
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
                    onPressed: _isLoading ? null : _signInWithEmailAndPassword,
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithFacebook,
                    icon: const Icon(
                      Icons.facebook,
                      size: 24,
                      color: Color(0xFF1877F2),
                    ),
                    label: const Text('Sign in with Facebook'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithYahoo,
                    icon: const Icon(
                      Icons.email,
                      size: 24,
                      color: Colors.purple,
                    ), // Yahoo purple generic icon
                    label: const Text('Sign in with Yahoo'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _showPhoneSignInDialog,
                    icon: const Icon(Icons.phone, size: 24),
                    label: const Text('Sign in with Phone'),
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
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    child: const Text('Don\'t have an account? Sign up'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
