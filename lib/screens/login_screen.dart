import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  
  bool _isParent = true; // Switch between parent and teacher roles
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

  // Regular login trigger
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

  // Biometric login trigger
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

  // Offers parent to enable biometric login after their first successful manual login
  Future<void> _checkAndOfferBiometricSetup() async {
    final canUse = await authService.canUseBiometrics();
    final alreadyEnabled = await authService.isBiometricEnabled();

    if (canUse && !alreadyEnabled && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'Kích hoạt Đăng nhập nhanh?',
            style: TextStyle(color: Color(0xFF1F2232), fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Bạn có muốn bật xác thực Vân tay / Khuôn mặt (Face ID) để đăng nhập nhanh hơn cho lần sau không?',
            style: TextStyle(color: const Color(0xFF2D3142).withOpacity(0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Bỏ qua', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () async {
                await authService.setBiometricEnabled(true);
                await authService.savePassword(_passwordController.text);
                setState(() {
                  _showBiometricBtn = true;
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Kích hoạt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC), // Clean light theme background
      body: Stack(
        children: [
          // Glassmorphic background shapes
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x1F6C63FF),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x15FF6584),
              ),
            ),
          ),

          // Main contents
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo
                    Center(
                      child: Hero(
                        tag: 'logo',
                        child: Image.asset('assets/logo.png', height: 50),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hệ thống Điểm danh & Liên lạc Nhà trường',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: const Color(0xFF2D3142).withOpacity(0.6), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 32),

                    // Role switch bar (Parents / Teachers)
                    Stack(
                      children: [
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _isParent = true),
                                  borderRadius: BorderRadius.circular(26),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _isParent ? const Color(0xFF6C63FF) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(26),
                                      boxShadow: _isParent
                                          ? [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                                          : [],
                                    ),
                                    child: Text(
                                      'Phụ Huynh',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: _isParent ? Colors.white : const Color(0xFF2D3142).withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _isParent = false),
                                  borderRadius: BorderRadius.circular(26),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: !_isParent ? const Color(0xFF6C63FF) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(26),
                                      boxShadow: !_isParent
                                          ? [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                                          : [],
                                    ),
                                    child: Text(
                                      'Giáo Viên',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: !_isParent ? Colors.white : const Color(0xFF2D3142).withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_hasSavedAccount)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Error message alert banner
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0x33FF6584),
                          border: Border.all(color: const Color(0xFFFF6584), width: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFFF6584), fontSize: 13),
                        ),
                      ),

                    // Login form inputs
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ID Input
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 12, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: TextFormField(
                              controller: _idController,
                              readOnly: _hasSavedAccount,
                              style: TextStyle(color: _hasSavedAccount ? Colors.grey : const Color(0xFF1F2232), fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: _isParent ? 'Mã Thẻ Học Sinh (e.g. 04E2D3B2)' : 'Tên đăng nhập giáo viên',
                                hintStyle: TextStyle(color: const Color(0xFF2D3142).withOpacity(0.4), fontSize: 14, fontWeight: FontWeight.normal),
                                prefixIcon: Icon(
                                  _isParent ? Icons.badge_rounded : Icons.person_rounded,
                                  color: const Color(0xFF6C63FF),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 20),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return _isParent ? 'Vui lòng nhập mã thẻ học sinh' : 'Vui lòng nhập tên đăng nhập';
                                }
                                return null;
                              },
                            ),
                          ),
                          if (_hasSavedAccount)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _switchAccount,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF6C63FF)),
                                label: const Text(
                                  'Đăng nhập bằng tài khoản khác',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6C63FF)),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),

                          // Password Input
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 12, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: Color(0xFF1F2232), fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: 'Mật khẩu',
                                hintStyle: TextStyle(color: const Color(0xFF2D3142).withOpacity(0.4), fontSize: 14, fontWeight: FontWeight.normal),
                                prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF6C63FF)),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    color: const Color(0xFF2D3142).withOpacity(0.4),
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 20),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Vui lòng nhập mật khẩu';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Login & Biometric Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6C63FF),
                                      disabledBackgroundColor: const Color(0x806C63FF),
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                          )
                                        : const Text(
                                            'Đăng Nhập',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              if (_showBiometricBtn) ...[
                                const SizedBox(width: 16),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 8)),
                                    ],
                                  ),
                                  child: InkWell(
                                    onTap: _isLoading ? null : _handleBiometricLogin,
                                    borderRadius: BorderRadius.circular(24),
                                    child: const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Icon(
                                        Icons.fingerprint_rounded,
                                        size: 28,
                                        color: Color(0xFF6C63FF),
                                      ),
                                    ),
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // "Setup/First Time password registration" link for parents
                    if (_isParent)
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SetupPasswordScreen()),
                            );
                          },
                          child: const Text(
                            'Thiết lập mật khẩu phụ huynh lần đầu?',
                            style: TextStyle(
                              color: Color(0xFF6C63FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
