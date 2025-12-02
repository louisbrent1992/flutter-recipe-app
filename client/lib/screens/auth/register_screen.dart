import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final TextEditingController _inviteCodeController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _inviteCodeInitialized = false;

  // Password requirement states
  bool _hasMinLength = false;
  bool _hasUpperCase = false;
  bool _hasLowerCase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  bool _hasNoSpaces = true;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePasswordRequirements);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inviteCodeInitialized) return;
    _inviteCodeInitialized = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    String? code;
    if (args is String) {
      code = args;
    } else if (args is Map) {
      code = args['inviteCode'] as String?;
    }
    if (code != null && code.isNotEmpty) {
      _inviteCodeController.text = code;
      return;
    }
  }

  void _validatePasswordRequirements() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUpperCase = password.contains(RegExp(r'[A-Z]'));
      _hasLowerCase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      _hasNoSpaces = !password.contains(' ');
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : lightSuccessColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
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
        if (message.contains('region') || message.contains('sms unable to be sent')) {
          return 'SMS verification is not available for your region. Please try another sign-in method.';
        }
        if (message.contains('blocked') || message.contains('unusual activity')) {
          return 'This device has been blocked due to unusual activity. Try again later.';
        }
        if (message.contains('network')) {
          return 'Network error. Please check your connection and try again.';
        }
        return 'Unable to verify phone number. Please try again.';
    }
  }

  String? _validatePassword() {
    final value = _passwordController.text;
    if (value.isEmpty) {
      return 'Please enter your password';
    }

    if (!_hasMinLength) {
      return 'Password must be at least 8 characters';
    }

    if (!_hasUpperCase) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!_hasLowerCase) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!_hasNumber) {
      return 'Password must contain at least one number';
    }

    if (!_hasSpecialChar) {
      return 'Password must contain at least one special character';
    }

    if (!_hasNoSpaces) {
      return 'Password cannot contain spaces';
    }

    return null;
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validatePasswordRequirements);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _registerWithEmailAndPassword() async {
    // Manual validation since CupertinoTextField doesn't support validators
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty) {
      _showSnackBar('Please enter your name', isError: true);
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar('Please enter a valid email', isError: true);
      return;
    }

    final passwordError = _validatePassword();
    if (passwordError != null) {
      _showSnackBar(passwordError, isError: true);
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar('Passwords do not match', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<AuthService>().registerWithEmailAndPassword(
        email,
        password,
        name,
      );
      if (mounted) {
        _showSnackBar('Registration successful! Please sign in to continue.');
        // Clear stack when going to login to ensure fresh start
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'An account already exists with this email.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'operation-not-allowed':
          message = 'Email/password accounts are not enabled.';
          break;
        case 'weak-password':
          message = 'Please choose a stronger password.';
          break;
        default:
          message = 'An error occurred during registration.';
      }
      _showSnackBar(message, isError: true);
    } catch (e) {
      _showSnackBar(
        'An unexpected error occurred. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final User? userData =
          await context.read<AuthService>().signInWithGoogle();
      if (mounted) {
        _showSnackBar('Successfully signed up with Google!');
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (route) => false,
          arguments: userData,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          message =
              'An account already exists with this email using a different sign-in method.';
          break;
        case 'invalid-credential':
          message = 'Invalid credentials. Please try again.';
          break;
        case 'operation-not-allowed':
          message = 'Google sign-in is not enabled.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        default:
          message = 'An error occurred during Google sign-up.';
      }
      _showSnackBar(message, isError: true);
    } catch (e) {
      _showSnackBar(
        'Failed to sign up with Google. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUpWithFacebook() async {
    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final user = await authService.signInWithFacebook();
      if (mounted && user != null) {
        _showSnackBar('Successfully signed up with Facebook!');
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else if (mounted && authService.error != null) {
        _showSnackBar(authService.error!, isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to sign up with Facebook.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUpWithYahoo() async {
    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final user = await authService.signInWithYahoo();
      if (mounted && user != null) {
        _showSnackBar('Successfully signed up with Yahoo!');
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else if (mounted && authService.error != null) {
        _showSnackBar(authService.error!, isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to sign up with Yahoo.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _showPhoneSignUpDialog() {
    final phoneController = TextEditingController();
    final codeController = TextEditingController();
    String? verificationId;
    bool codeSent = false;
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(codeSent ? 'Enter Verification Code' : 'Enter Phone Number'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      errorText!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                if (!codeSent) ...[
                  CupertinoTextField(
                    controller: phoneController,
                    placeholder: '+1 555 555 5555',
                    placeholderStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ]
                else
                  CupertinoTextField(
                    controller: codeController,
                    placeholder: 'SMS Code',
                    placeholderStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
                  )
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
                        onVerificationCompleted: (credential) {
                          // Auto verification (Android)
                          if (context.mounted) {
                            Navigator.pop(context);
                            Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
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
                        final user = await authService.signInWithPhoneCredential(verificationId!, code);
                        if (user != null && context.mounted) {
                          Navigator.pop(context);
                          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                        } else if (context.mounted) {
                          String friendlyError = 'The verification code is incorrect. Please try again.';
                          final error = authService.error?.toLowerCase() ?? '';
                          if (error.contains('expired') || error.contains('session')) {
                            friendlyError = 'The verification code has expired. Please request a new code.';
                          } else if (error.contains('invalid')) {
                            friendlyError = 'The verification code is incorrect. Please try again.';
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

  Future<void> _signUpWithApple() async {
    setState(() => _isLoading = true);

    try {
      final User? userData =
          await context.read<AuthService>().signInWithApple();
      if (mounted) {
        _showSnackBar('Successfully signed up with Apple!');
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (route) => false,
          arguments: userData,
        );
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case AuthorizationErrorCode.canceled:
          message =
              'Sign up was canceled. Please try again when you\'re ready.';
          break;
        case AuthorizationErrorCode.failed:
          message = 'Sign up failed. Please try again.';
          break;
        case AuthorizationErrorCode.invalidResponse:
          message = 'Invalid response from Apple. Please try again.';
          break;
        case AuthorizationErrorCode.notHandled:
          message = 'Sign up could not be completed. Please try again.';
          break;
        case AuthorizationErrorCode.unknown:
        default:
          message = 'An unexpected error occurred. Please try again.';
      }
      _showSnackBar(message, isError: true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          message =
              'An account already exists with this email using a different sign-in method.';
          break;
        case 'invalid-credential':
          message = 'Invalid credentials. Please try again.';
          break;
        case 'operation-not-allowed':
          message = 'Apple sign-in is not enabled.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        default:
          message = 'An error occurred during Apple sign-up.';
      }
      _showSnackBar(message, isError: true);
    } catch (e) {
      _showSnackBar(
        'Failed to sign up with Apple. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Scrollbar(
            thumbVisibility: true,
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create Account',
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
                    CupertinoTextField(
                      controller: _nameController,
                      placeholder: 'Full Name',
                      placeholderStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      textInputAction: TextInputAction.next,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: _emailController,
                      placeholder: 'Email',
                      placeholderStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: _passwordController,
                      placeholder: 'Password',
                      placeholderStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      style: TextStyle(
                        color: colorScheme.onSurface,
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
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Password must be at least 8 characters long and contain:',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.secondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _buildRequirementText(
                            'At least one uppercase letter (A-Z)',
                            _hasUpperCase,
                          ),
                          _buildRequirementText(
                            'At least one lowercase letter (a-z)',
                            _hasLowerCase,
                          ),
                          _buildRequirementText(
                            'At least one number (0-9)',
                            _hasNumber,
                          ),
                          _buildRequirementText(
                            'At least one special character (!@#\$%^&*(),.?":{}|<>)',
                            _hasSpecialChar,
                          ),
                          _buildRequirementText(
                            'No spaces allowed',
                            _hasNoSpaces,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: _confirmPasswordController,
                      placeholder: 'Confirm Password',
                      placeholderStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                      ),
                      suffix: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                          child: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _registerWithEmailAndPassword(),
                    ),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: _inviteCodeController,
                      placeholder: 'Invite Code (optional)',
                      placeholderStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Use an invite code to earn bonus credits for you and your friend.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed:
                          _isLoading ? null : _registerWithEmailAndPassword,
                      child:
                          _isLoading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                              : const Text('Sign Up'),
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
                      onPressed: _isLoading ? null : _signUpWithGoogle,
                      icon: Image.network(
                        'https://www.google.com/favicon.ico',
                        height:
                            AppBreakpoints.isDesktop(context)
                                ? 28
                                : AppBreakpoints.isTablet(context)
                                ? 26
                                : 24,
                        errorBuilder:
                            (_, __, ___) =>
                                const Icon(Icons.g_mobiledata, size: 24),
                      ),
                      label: const Text('Sign up with Google'),
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
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signUpWithFacebook,
                      icon: const Icon(Icons.facebook, size: 24, color: Color(0xFF1877F2)),
                      label: const Text('Sign up with Facebook'),
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
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signUpWithYahoo,
                      icon: const Icon(Icons.email, size: 24, color: Colors.purple),
                      label: const Text('Sign up with Yahoo'),
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
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _showPhoneSignUpDialog,
                      icon: const Icon(Icons.phone, size: 24),
                      label: const Text('Sign up with Phone'),
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
                              onPressed: _isLoading ? null : _signUpWithApple,
                              icon: Icon(
                                Icons.apple,
                                size:
                                    AppBreakpoints.isDesktop(context)
                                        ? 28
                                        : AppBreakpoints.isTablet(context)
                                        ? 26
                                        : 24,
                              ),
                              label: const Text('Sign up with Apple'),
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
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: const Text('Already have an account? Sign in'),
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

  Widget _buildRequirementText(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, top: 1.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_rounded,
            size: 14,
            color: isMet ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isMet ? Colors.green : Colors.grey,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
