import 'package:firebase_auth/firebase_auth.dart';
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
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final User? user = FirebaseAuth.instance.currentUser;

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
    _confirmPasswordController.addListener(_validatePasswordMatch);
    _emailController.addListener(_onEmailChanged);
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

  void _onEmailChanged() {
    setState(() {});
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
        Navigator.pushReplacementNamed(context, '/login');
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
        Navigator.pushNamed(context, '/home', arguments: userData);
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
      print('userData: $userData');
      if (mounted) {
        _showSnackBar('Successfully signed up with Apple!');
        Navigator.pushNamed(context, '/home', arguments: userData);
      }
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
                maxWidth: AppBreakpoints.isDesktop(context)
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
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: AppTypography.responsiveHeadingSize(
                          context,
                          mobile: 28,
                          tablet: 34,
                          desktop: 40,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(
                      height: AppBreakpoints.isDesktop(context)
                          ? 40
                          : AppBreakpoints.isTablet(context)
                              ? 36
                              : 32,
                    ),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: const OutlineInputBorder(),
                      errorText:
                          _nameController.text.isEmpty &&
                                  _nameController.text.isNotEmpty
                              ? 'Please enter your name'
                              : null,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: const OutlineInputBorder(),
                      errorText:
                          _emailController.text.isNotEmpty &&
                                  !_emailController.text.contains('@')
                              ? 'Please enter a valid email'
                              : null,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
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
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Password must be at least 8 characters long and contain:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 4),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      errorText:
                          _confirmPasswordController.text.isNotEmpty &&
                                  _confirmPasswordController.text !=
                                      _passwordController.text
                              ? 'Passwords do not match'
                              : null,
                    ),
                    obscureText: _obscureConfirmPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
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
                      height: AppBreakpoints.isDesktop(context)
                          ? 28
                          : AppBreakpoints.isTablet(context)
                              ? 26
                              : 24,
                    ),
                    label: const Text('Sign up with Google'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: AppBreakpoints.isDesktop(context)
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
                              size: AppBreakpoints.isDesktop(context)
                                  ? 28
                                  : AppBreakpoints.isTablet(context)
                                      ? 26
                                      : 24,
                            ),
                            label: const Text('Sign up with Apple'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: AppBreakpoints.isDesktop(context)
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
                      Navigator.pop(context);
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
      padding: const EdgeInsets.only(left: 8.0, top: 2.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_rounded,
            size: 16,
            color: isMet ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isMet ? Colors.green : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
