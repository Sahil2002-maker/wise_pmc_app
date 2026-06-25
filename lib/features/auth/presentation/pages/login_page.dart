import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../widgets/brand_header.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/field_label.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final usernameOrEmail = TextEditingController();
  final password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // ── State ─────────────────────────────────────────────────────────────────
  bool isLoading = false;
  bool rememberMe = false;
  String? _errorMessage;

  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  // ── Allowed roles ─────────────────────────────────────────────────────────
  static const _allowedRoles = {
    'admin',
    'teamleader',
    'manager',
    'executive',
    'employee',
    'receptionist', // ← ADD any additional roles here
  };

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    usernameOrEmail.dispose();
    password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── Validators ────────────────────────────────────────────────────────────
  String? usernameOrEmailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username / Email is required';
    }
    return null;
  }

  String? passwordValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.login(
        usernameOrEmail: usernameOrEmail.text.trim(),
        password: password.text.trim(),
      );

      if (!mounted) return;

      final user = result['user'] as Map<String, dynamic>? ?? {};
      final role = (user['role']?.toString() ?? '').toLowerCase().trim();

      // ── Role check BEFORE showing success snackbar ────────────────────
      if (!_allowedRoles.contains(role)) {
        setState(() {
          _errorMessage =
              'Access denied. Your role "$role" is not permitted in this app.';
          isLoading = false;
        });
        return;
      }

      // ── Success ───────────────────────────────────────────────────────
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primaryGreen,
          content: Text(
            'Login successful',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } catch (e) {
      if (!mounted) return;

      final message = e is ApiException ? e.message : e.toString();
      setState(() {
        _errorMessage = message;
        isLoading = false;
      });
    }
  }

  void openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _BackgroundCards(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: SlideTransition(
                    position: _slideUp,
                    child: _buildCard(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Brand Header ──────────────────────────────────────────────
            const BrandHeader(),
            const SizedBox(height: 24),

            // ── Title ─────────────────────────────────────────────────────
            const Text(
              'Login',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 24),

            // ── Error Banner ──────────────────────────────────────────────
            if (_errorMessage != null) ...[
              _ErrorBanner(message: _errorMessage!),
              const SizedBox(height: 16),
            ],

            // ── Username / Email ──────────────────────────────────────────
            const FieldLabel(text: 'Username / Email', requiredField: true),
            const SizedBox(height: 6),
            CustomTextField(
              hintText: 'Enter username or email',
              controller: usernameOrEmail,
              validator: usernameOrEmailValidator,
              keyboardType: TextInputType.text,
              autofocus: true,
            ),
            const SizedBox(height: 16),

            // ── Password Row ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const FieldLabel(text: 'Password', requiredField: true),
                GestureDetector(
                  onTap: openForgotPassword,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            CustomTextField(
              hintText: 'Enter password',
              controller: password,
              validator: passwordValidator,
              isPassword: true,
            ),
            const SizedBox(height: 16),

            // ── Remember Me ───────────────────────────────────────────────
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: rememberMe,
                    onChanged: (v) => setState(() => rememberMe = v ?? false),
                    activeColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    side: const BorderSide(
                      color: AppColors.borderColor,
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Remember Me',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Sign In Button ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primaryGreen.withValues(alpha: 0.75),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.requiredRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.requiredRed.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.requiredRed, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppColors.requiredRed, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundCards extends StatelessWidget {
  const _BackgroundCards();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: size.height * 0.1,
            left: size.width * 0.1,
            child: _DecorCard(
              width: size.width * 0.5,
              height: size.height * 0.25,
              borderRadius: 20,
              color: AppColors.decorCard1,
            ),
          ),
          Positioned(
            bottom: size.height * 0.08,
            right: size.width * 0.05,
            child: _DecorCard(
              width: size.width * 0.45,
              height: size.height * 0.2,
              borderRadius: 20,
              color: AppColors.decorCard2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorCard extends StatelessWidget {
  final double width, height, borderRadius;
  final Color color;

  const _DecorCard({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}