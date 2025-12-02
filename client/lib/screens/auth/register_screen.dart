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
  final _formKey = GlobalKey<FormState>();
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

  String? _emailError;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePasswordRequirements);
    _confirmPasswordController.addListener(_validatePasswordMatch);
    _emailController.addListener(_onEmailChanged);
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

  void _validatePasswordMatch() {
    if (_confirmPasswordController.text.isNotEmpty) {
      setState(() {});
    }
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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
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

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!value.contains('@')) {
      return 'Please enter a valid email';
    }
    return null;
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validatePasswordRequirements);
    _confirmPasswordController.removeListener(_validatePasswordMatch);
    _emailController.removeListener(_onEmailChanged);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _registerWithEmailAndPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await context.read<AuthService>().registerWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
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
      body: Center(
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
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CupertinoTextField(
                        controller: _emailController,
                        placeholder: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                _emailError != null
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.outline,
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
                      if (_emailError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 12),
                          child: Text(
                            _emailError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: _passwordController,
                    placeholder: 'Password',
                    obscureText: _obscurePassword,
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
                    obscureText: _obscureConfirmPassword,
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
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        child: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: _inviteCodeController,
                    placeholder: 'Invite Code (optional)',
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
                            ? const CircularProgressIndicator()
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
