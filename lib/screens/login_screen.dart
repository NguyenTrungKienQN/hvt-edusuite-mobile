import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import 'setup_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isParent = true;
  bool _obscurePassword = true;
  bool _showBiometricBtn = false;
  bool _isLoading = false;
  bool _hasSavedAccount = false;
  String? _errorMessage;
  
  // Fauget Theme Primary Color
  final Color _primaryColor = const Color(0xFF7943FA);

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    _loadSavedAccount();
  }

  Future<void> _loadSavedAccount() async {
    final creds = await authService.getSavedCredentialsInfo();
    if (creds['identifier'] != null && creds['identifier']!.isNotEmpty) {
      setState(() {
        _idController.text = creds['identifier']!;
        _isParent = creds['role'] == 'parent';
        _hasSavedAccount = true;
      });
    }
  }

  void _switchAccount() {
    setState(() {
      _hasSavedAccount = false;
      _idController.clear();
      _passwordController.clear();
      _showBiometricBtn = false;
      _errorMessage = null;
    });
    authService.saveCredentialsInfo('', '');
    authService.setBiometricEnabled(false);
  }

  Future<void> _checkBiometricAvailability() async {
    final canCheck = await authService.canUseBiometrics();
    final enabled = await authService.isBiometricEnabled();
    setState(() {
      _showBiometricBtn = canCheck && enabled;
    });
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await ref.read(authProvider.notifier).login(
      role: _isParent ? 'parent' : 'teacher',
      identifier: _idController.text.trim(),
      password: _passwordController.text,
    );

    if (mounted) {
      if (!success) {
        setState(() {
          _isLoading = false;
          _errorMessage = ref.read(authProvider).errorMessage;
        });
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await ref.read(authProvider.notifier).loginWithBiometrics();
    
    if (mounted) {
      if (!success) {
        setState(() {
          _isLoading = false;
          _errorMessage = ref.read(authProvider).errorMessage ?? 'Xác thực vân tay thất bại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Logo
              Hero(
                tag: 'logo',
                child: Image.asset('assets/logo.png', height: 36),
              ),
              const SizedBox(height: 32),

              // 2. Greeting Texts
              const Text(
                'Xin chào!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3142),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Chào mừng đến với HVT EduSuite',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3142),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Vui lòng đăng nhập để tiếp tục.',
                style: TextStyle(
                  fontSize: 15,
                  color: const Color(0xFF2D3142).withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),

              // 3. Illustration
              Center(
                child: Image.asset(
                  'assets/Resources/1.png',
                  height: 220,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),

              // Error Message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    border: Border.all(color: const Color(0xFFFF6584).withValues(alpha: 0.5), width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFFF6584), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFFF6584), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

              // 4. Role Toggle
              _buildRoleToggle(),
              const SizedBox(height: 24),

              // 5. Login Form
              _buildLoginForm(),
              const SizedBox(height: 24),

              // 6. Setup Password Footer
              if (_isParent)
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SetupPasswordScreen()));
                    },
                    child: RichText(
                      text: TextSpan(
                        text: 'Phụ huynh chưa có mật khẩu? ',
                        style: TextStyle(color: const Color(0xFF2D3142).withValues(alpha: 0.6), fontSize: 14),
                        children: [
                          TextSpan(
                            text: 'Thiết lập ngay',
                            style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 32),
              _buildDemoMode(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleToggle() {
    return Stack(
      children: [
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          padding: const EdgeInsets.all(4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / 2;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    left: _isParent ? 0 : tabWidth,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isParent = true),
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: _isParent ? _primaryColor : const Color(0xFF2D3142).withValues(alpha: 0.5),
                              ),
                              child: const Text('Phụ Huynh'),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isParent = false),
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: !_isParent ? _primaryColor : const Color(0xFF2D3142).withValues(alpha: 0.5),
                              ),
                              child: const Text('Giáo Viên'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        if (_hasSavedAccount)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Input 1: ID
          _buildInputField(
            controller: _idController,
            readOnly: _hasSavedAccount,
            hintText: _isParent ? 'Mã thẻ / Số điện thoại' : 'Tên đăng nhập',
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return _isParent ? 'Vui lòng nhập mã thẻ' : 'Vui lòng nhập tên đăng nhập';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Input 2: Password
          _buildInputField(
            controller: _passwordController,
            hintText: 'Mật khẩu',
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF2D3142).withValues(alpha: 0.4),
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Vui lòng nhập mật khẩu';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Remember Me (Biometrics) & Forgot Password Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Biometrics replace "Remember Me" if available/enabled
              if (_showBiometricBtn)
                InkWell(
                  onTap: _isLoading ? null : _handleBiometricLogin,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fingerprint_rounded, color: _primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Đăng nhập vân tay',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2D3142).withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_hasSavedAccount)
                TextButton.icon(
                  onPressed: _switchAccount,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(Icons.swap_horiz_rounded, size: 18, color: _primaryColor),
                  label: Text(
                    'Đổi tài khoản',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _primaryColor),
                  ),
                )
              else
                const SizedBox(), // Empty space for alignment

              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Quên mật khẩu?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2D3142).withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // SIGN IN Button
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                disabledBackgroundColor: _primaryColor.withValues(alpha: 0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text(
                      'ĐĂNG NHẬP',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    bool readOnly = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        // Extremely subtle shadow matching the design
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        readOnly: readOnly,
        style: TextStyle(
          color: readOnly ? Colors.grey : const Color(0xFF2D3142), 
          fontWeight: FontWeight.w500, 
          fontSize: 15
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: const Color(0xFF2D3142).withValues(alpha: 0.4), 
            fontSize: 15, 
            fontWeight: FontWeight.normal
          ),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), 
            borderSide: BorderSide.none,
          ),
          // Slight padding to match the exact aesthetic of Fauget inputs
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDemoMode() {
    if (!kDebugMode) return const SizedBox();
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Demo Mode',
                style: TextStyle(
                  fontSize: 12, 
                  color: const Color(0xFF2D3142).withValues(alpha: 0.4), 
                  fontWeight: FontWeight.w500
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.2))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => ref.read(authProvider.notifier).loginDemo('parent'),
              child: Text('Phụ Huynh', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () => ref.read(authProvider.notifier).loginDemo('teacher'),
              child: Text('Giáo Viên', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }
}

// Make from Kiên and Dương with love
