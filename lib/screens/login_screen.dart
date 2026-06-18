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
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: const Color(0xFFE2E8F4), // Base fallback
      body: Stack(
        children: [
          // 1. Soft Pastel Gradient Background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: screenHeight * 0.4,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE6E6FA), // Light lavender
                    Color(0xFFE0E7FF), // Pale blue
                  ],
                ),
              ),
            ),
          ),
          
          // 2. Centered Branding Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.32,
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Hero(
                        tag: 'logo',
                        child: Image.asset('assets/logo.png', height: 60),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Hệ thống Điểm danh & Liên lạc Nhà trường',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF2D3142).withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // 3. Bottom White Sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Dynamically occupy roughly 65-75% of screen height
                final sheetHeight = screenHeight * 0.68;
                return Container(
                  height: sheetHeight,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x08000000), // Extremely soft shadow
                        blurRadius: 40,
                        offset: Offset(0, -10),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildRoleToggle(),
                          const SizedBox(height: 32),
                          
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: const Color(0x33FF6584),
                                border: Border.all(color: const Color(0xFFFF6584), width: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Color(0xFFFF6584), fontSize: 13),
                              ),
                            ),
                            
                          _buildLoginForm(),
                          const SizedBox(height: 32),
                          _buildDemoMode(),
                        ],
                      ),
                    ),
                  ),
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleToggle() {
    return Stack(
      children: [
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7FC),
            borderRadius: BorderRadius.circular(26),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: _isParent ? const Color(0xFF1F2232) : const Color(0xFF2D3142).withValues(alpha: 0.5),
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
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: !_isParent ? const Color(0xFF1F2232) : const Color(0xFF2D3142).withValues(alpha: 0.5),
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
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(26),
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
          // User Input
          Text(
            _isParent ? 'Mã thẻ / Tên đăng nhập' : 'Tên đăng nhập',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2232)),
          ),
          const SizedBox(height: 8),
          _buildInputField(
            controller: _idController,
            readOnly: _hasSavedAccount,
            hintText: _isParent ? 'VD: 04E2D3B2' : 'Nhập tài khoản giáo viên',
            icon: _isParent ? Icons.badge_outlined : Icons.person_outline,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return _isParent ? 'Vui lòng nhập mã thẻ' : 'Vui lòng nhập tên đăng nhập';
              }
              return null;
            },
          ),
          
          if (_hasSavedAccount)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _switchAccount,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF6C63FF)),
                label: const Text(
                  'Đăng nhập tài khoản khác',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6C63FF)),
                ),
              ),
            )
          else
            const SizedBox(height: 20),

          // Password Input
          const Text(
            'Mật khẩu',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2232)),
          ),
          const SizedBox(height: 8),
          _buildInputField(
            controller: _passwordController,
            hintText: 'Nhập mật khẩu',
            icon: Icons.lock_outline_rounded,
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
          
          // Forgot Password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Quên mật khẩu?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D3142).withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          
          // Login Button
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.3), 
                        blurRadius: 15, 
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      disabledBackgroundColor: const Color(0x806C63FF),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text(
                            'Đăng Nhập',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ),
              if (_showBiometricBtn) ...[
                const SizedBox(width: 16),
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                  ),
                  child: InkWell(
                    onTap: _isLoading ? null : _handleBiometricLogin,
                    borderRadius: BorderRadius.circular(28),
                    child: const Center(
                      child: Icon(Icons.fingerprint_rounded, size: 28, color: Color(0xFF6C63FF)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          // Setup First Password
          if (_isParent)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SetupPasswordScreen()));
                  },
                  child: const Text(
                    'Thiết lập mật khẩu phụ huynh lần đầu?',
                    style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.w600, fontSize: 14),
                  ),
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
    required IconData icon,
    bool obscureText = false,
    bool readOnly = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        readOnly: readOnly,
        style: TextStyle(color: readOnly ? Colors.grey : const Color(0xFF1F2232), fontWeight: FontWeight.w500, fontSize: 15),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: const Color(0xFF2D3142).withValues(alpha: 0.4), fontSize: 15, fontWeight: FontWeight.normal),
          prefixIcon: Icon(icon, color: const Color(0xFF2D3142).withValues(alpha: 0.4), size: 22),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
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
                'Hoặc thử nghiệm với',
                style: TextStyle(fontSize: 12, color: const Color(0xFF2D3142).withValues(alpha: 0.4), fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.2))),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => ref.read(authProvider.notifier).loginDemo('parent'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color(0xFF2D3142).withValues(alpha: 0.1), width: 1),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                icon: Icon(Icons.people_alt_outlined, color: const Color(0xFF2D3142).withValues(alpha: 0.6), size: 18),
                label: Text(
                  'Demo Phụ Huynh',
                  style: TextStyle(color: const Color(0xFF2D3142).withValues(alpha: 0.7), fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => ref.read(authProvider.notifier).loginDemo('teacher'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color(0xFF2D3142).withValues(alpha: 0.1), width: 1),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                icon: Icon(Icons.school_outlined, color: const Color(0xFF2D3142).withValues(alpha: 0.6), size: 18),
                label: Text(
                  'Demo Giáo Viên',
                  style: TextStyle(color: const Color(0xFF2D3142).withValues(alpha: 0.7), fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
