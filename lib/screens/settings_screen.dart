import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  final String role; // 'parent' or 'teacher'
  final dynamic data; // StudentModel (if parent) or UserModel (if teacher)
  final VoidCallback onLogout;
  final VoidCallback? onReload;
  final void Function(String)? onParentNameChanged;

  const SettingsScreen({
    super.key,
    required this.role,
    required this.data,
    required this.onLogout,
    this.onReload,
    this.onParentNameChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _isBiometricSupported = false;
  String? _parentName;

  @override
  void initState() {
    super.initState();
    if (widget.role == 'parent') {
      _parentName = widget.data.tenPhuHuynh;
    }
    _loadBiometricSettings();
  }

  Future<void> _loadBiometricSettings() async {
    final supported = await authService.canUseBiometrics();
    final enabled = await authService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _isBiometricSupported = supported;
        _biometricEnabled = enabled;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final authenticated = await authService.authenticateWithBiometrics();
      if (!authenticated) {
        if (mounted) {
          setState(() => _biometricEnabled = false);
        }
        return;
      }

      if (authService.sessionPassword != null) {
        await authService.savePassword(authService.sessionPassword!);
        await authService.setBiometricEnabled(true);
        if (mounted) {
          setState(() => _biometricEnabled = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Đã kích hoạt đăng nhập bằng vân tay/khuôn mặt.')),
          );
        }
      } else {
        // Prompt for password
        final pwd = await _showPasswordConfirmationDialog();
        if (pwd != null) {
          authService.sessionPassword = pwd;
          await authService.savePassword(pwd);
          await authService.setBiometricEnabled(true);
          if (mounted) {
            setState(() => _biometricEnabled = true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Đã kích hoạt đăng nhập bằng vân tay/khuôn mặt.')),
            );
          }
        } else {
          if (mounted) {
            setState(() => _biometricEnabled = false);
          }
        }
      }
    } else {
      await authService.setBiometricEnabled(false);
      await authService.deleteSavedPassword();
      if (mounted) {
        setState(() => _biometricEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Đã tắt đăng nhập bằng vân tay/khuôn mặt.')),
        );
      }
    }
  }

  Future<String?> _showPasswordConfirmationDialog() async {
    final passwordController = TextEditingController();
    bool obscureText = true;
    bool dialogLoading = false;
    String? dialogError;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'Xác nhận mật khẩu',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2232)),
              ),
              content: Padding(
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Nhập mật khẩu hiện tại để kích hoạt tính năng đăng nhập nhanh.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    if (dialogError != null) ...[
                      Text(
                        dialogError!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscureText,
                      decoration: InputDecoration(
                        hintText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF6C63FF)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: Colors.grey,
                          ),
                          onPressed: () => setDialogState(() => obscureText = !obscureText),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogLoading ? null : () {
                    Navigator.pop(context, null);
                  },
                  child: const Text('Hủy', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  onPressed: dialogLoading ? null : () async {
                    if (passwordController.text.isEmpty) {
                      setDialogState(() => dialogError = 'Vui lòng nhập mật khẩu');
                      return;
                    }
                    setDialogState(() {
                      dialogLoading = true;
                      dialogError = null;
                    });

                    try {
                      final String identifier = widget.role == 'parent' 
                          ? widget.data.uidThe 
                          : widget.data.username;
                      
                      final response = await apiService.login(
                        role: widget.role,
                        identifier: identifier,
                        password: passwordController.text,
                      );

                      if (response.statusCode == 200 || response.statusCode == 201) {
                        Navigator.pop(context, passwordController.text);
                      } else {
                        setDialogState(() {
                          dialogError = 'Mật khẩu không chính xác';
                          dialogLoading = false;
                        });
                      }
                    } catch (e) {
                      setDialogState(() {
                        dialogError = 'Mật khẩu không chính xác hoặc lỗi kết nối';
                        dialogLoading = false;
                      });
                    }
                  },
                  child: dialogLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Xác nhận', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
    passwordController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF6C63FF);

    // Dynamic fields based on role
    final String displayName = widget.role == 'parent'
        ? (_parentName != null && _parentName!.isNotEmpty
            ? _parentName!
            : 'Phụ huynh em ${widget.data.ten}')
        : widget.data.accountname;
    final String subHeader = widget.role == 'parent' ? 'Phụ huynh học sinh' : 'Giáo viên chủ nhiệm';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Profile Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, const Color(0xFF8A84FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))
                ],
              ),
              child: Column(
                children: [
                  // Avatar removed per request
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subHeader,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 2. Teacher Credentials Card (only shown for teachers)
            if (widget.role == 'teacher') ...[
              const Text(
                'Thông tin tài khoản',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2232)),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 16, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  children: [
                    _buildDetailRow(Icons.account_circle_outlined, 'Tên đăng nhập', widget.data.username),
                    const Divider(height: 24),
                    _buildDetailRow(Icons.badge_outlined, 'Mã định danh', widget.data.id.toString()),
                    const Divider(height: 24),
                    _buildDetailRow(Icons.assignment_ind_outlined, 'Lớp chủ nhiệm', widget.data.lopQuyen ?? 'Không có'),
                    const Divider(height: 24),
                    _buildDetailRow(Icons.security_rounded, 'Chức vụ', 'Giáo viên'),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],

            // 3. Biometric Switch Settings Card
            if (_isBiometricSupported) ...[
              const Text(
                'Tính năng hệ thống',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2232)),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 16, offset: const Offset(0, 4))
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.fingerprint_rounded, color: primaryColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sinh trắc học',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Đăng nhập nhanh bằng vân tay/khuôn mặt.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _biometricEnabled,
                      activeColor: primaryColor,
                      onChanged: _toggleBiometric,
                    )
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],

            // 4. Security settings & Change Password Card
            const Text(
              'Bảo mật & Thiết lập',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2232)),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 16, offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  if (widget.role == 'parent') ...[
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                        onTap: () => _showUpdateParentNameDialog(_parentName),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFFE8F0FE),
                                child: Icon(Icons.person_outline_rounded, color: Color(0xFF1A73E8)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Cập nhật Họ tên Phụ huynh',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _parentName != null && _parentName!.isNotEmpty
                                          ? 'Hiện tại: $_parentName'
                                          : 'Chưa thiết lập tên phụ huynh',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                  ],
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: widget.role == 'parent'
                          ? const BorderRadius.only(
                              bottomLeft: Radius.circular(24),
                              bottomRight: Radius.circular(24),
                            )
                          : BorderRadius.circular(24),
                      onTap: _showChangePasswordDialog,
                      child: const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Color(0xFFFFF0E6),
                              child: Icon(Icons.key_rounded, color: Color(0xFFFF9F43)),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Đổi mật khẩu',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Thay đổi mật khẩu đăng nhập ứng dụng.',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 5. System Info Card (Moved from Tiện ích)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 16, offset: const Offset(0, 4))
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông tin hệ thống',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Phiên bản ứng dụng', '1.0.0 (Release)'),
                  const SizedBox(height: 12),
                  _buildInfoRow('Trạng thái kết nối', 'Trực tuyến'),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // 6. Log out Action
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                label: const Text(
                  'Đăng xuất khỏi ứng dụng',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4949),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 22),
        const SizedBox(width: 16),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3142), fontSize: 14)),
      ],
    );
  }



  Future<void> _showChangePasswordDialog() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool loading = false;
    String? error;
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'Đổi mật khẩu',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2232)),
              ),
              content: Padding(
                padding: EdgeInsets.zero,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (error != null) ...[
                        Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                        const SizedBox(height: 8),
                      ],
                      TextFormField(
                        controller: oldPasswordController,
                        obscureText: obscureOld,
                        decoration: InputDecoration(
                          hintText: 'Mật khẩu hiện tại',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF6C63FF)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureOld ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: Colors.grey,
                            ),
                            onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          hintText: 'Mật khẩu mới',
                          prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF6C63FF)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: Colors.grey,
                            ),
                            onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          hintText: 'Xác nhận mật khẩu mới',
                          prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF6C63FF)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: Colors.grey,
                            ),
                            onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(context),
                  child: const Text('Hủy', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  onPressed: loading ? null : () async {
                    if (oldPasswordController.text.isEmpty) {
                      setDialogState(() => error = 'Vui lòng nhập mật khẩu hiện tại');
                      return;
                    }
                    if (newPasswordController.text.length < 6) {
                      setDialogState(() => error = 'Mật khẩu mới phải dài ít nhất 6 ký tự');
                      return;
                    }
                    if (confirmPasswordController.text != newPasswordController.text) {
                      setDialogState(() => error = 'Mật khẩu xác nhận không trùng khớp');
                      return;
                    }
                    setDialogState(() {
                      loading = true;
                      error = null;
                    });

                    try {
                      final response = await apiService.changePassword(
                        oldPassword: oldPasswordController.text,
                        newPassword: newPasswordController.text,
                      );

                      if (response.statusCode == 200 || response.statusCode == 201) {
                        final isBioEnabled = await authService.isBiometricEnabled();
                        if (isBioEnabled) {
                          await authService.savePassword(newPasswordController.text);
                        }
                        if (authService.sessionPassword != null) {
                          authService.sessionPassword = newPasswordController.text;
                        }

                        if (context.mounted) {
                          Navigator.pop(context, true);
                        }
                      } else {
                        setDialogState(() {
                          error = 'Mật khẩu cũ không chính xác hoặc lỗi cập nhật.';
                          loading = false;
                        });
                      }
                    } on DioException catch (e) {
                      String errMsg = 'Lỗi cập nhật mật khẩu.';
                      if (e.response != null && e.response!.data != null) {
                        final data = e.response!.data;
                        if (data is Map && data.containsKey('detail')) {
                          errMsg = data['detail'].toString();
                        }
                      }
                      setDialogState(() {
                        error = errMsg;
                        loading = false;
                      });
                    } catch (e) {
                      setDialogState(() {
                        error = 'Lỗi kết nối máy chủ.';
                        loading = false;
                      });
                    }
                  },
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Lưu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Đổi mật khẩu thành công.')),
      );
    }
  }

  Future<void> _showUpdateParentNameDialog(String? currentName) async {
    final controller = TextEditingController(text: currentName);
    bool loading = false;
    String? error;

    final newName = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'Cập nhật tên phụ huynh',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2232)),
              ),
              content: Padding(
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Nhập họ tên đầy đủ của phụ huynh học sinh.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    if (error != null) ...[
                      Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      const SizedBox(height: 8),
                    ],
                    TextFormField(
                      controller: controller,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'Họ và tên Phụ huynh',
                        prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF6C63FF)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(context, null),
                  child: const Text('Hủy', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  onPressed: loading ? null : () async {
                    if (controller.text.trim().isEmpty) {
                      setDialogState(() => error = 'Vui lòng nhập họ tên');
                      return;
                    }
                    setDialogState(() {
                      loading = true;
                      error = null;
                    });

                    try {
                      final response = await apiService.updateParentName(controller.text.trim());
                      if (response.statusCode == 200 || response.statusCode == 201) {
                        Navigator.pop(context, controller.text.trim());
                      } else {
                        setDialogState(() {
                          error = 'Không thể cập nhật tên. Vui lòng thử lại.';
                          loading = false;
                        });
                      }
                    } catch (e) {
                      setDialogState(() {
                        error = 'Không thể cập nhật tên. Vui lòng thử lại.';
                        loading = false;
                      });
                    }
                  },
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Lưu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();

    if (newName != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Cập nhật họ tên thành công')),
      );
      if (widget.onReload != null) {
        widget.onReload!();
      }
    }
  }
}
