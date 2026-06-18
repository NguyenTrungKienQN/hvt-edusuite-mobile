import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

class SetupPasswordScreen extends StatefulWidget {
  const SetupPasswordScreen({super.key});

  @override
  State<SetupPasswordScreen> createState() => _SetupPasswordScreenState();
}

class _SetupPasswordScreenState extends State<SetupPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uidController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _uidController.dispose();
    _parentNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }



  // Handles calling API to register password
  Future<void> _handleSetup() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await apiService.setupParentPassword(
        uidThe: _uidController.text.trim(),
        newPassword: _passwordController.text,
        tenPhuHuynh: _parentNameController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.data['message'] ?? 'Thiết lập mật khẩu thành công!')),
        );
        Navigator.pop(context); // Go back to login screen
      }
    } on DioException catch (e) {
      String errMsg = 'Lỗi kết nối máy chủ';
      if (e.response != null && e.response!.data != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('detail')) {
          final detailVal = data['detail'];
          if (detailVal is String) {
            errMsg = detailVal;
          } else if (detailVal is List) {
            try {
              errMsg = detailVal.map((e) => e['msg'] ?? '').join(', ');
            } catch (_) {
              errMsg = detailVal.toString();
            }
          } else {
            errMsg = detailVal.toString();
          }
        }
      }
      setState(() {
        _errorMessage = errMsg;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F2232)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Thiết Lập Mật Khẩu Lần Đầu',
          style: TextStyle(color: Color(0xFF1F2232), fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Đăng ký Mật khẩu Phụ huynh',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2232)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vui lòng nhập Mã thẻ RFID học sinh để xác minh danh tính phụ huynh và thiết lập mật khẩu.',
                    style: TextStyle(fontSize: 14, color: const Color(0xFF2D3142).withOpacity(0.6)),
                  ),
                  const SizedBox(height: 32),

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

                  // RFID Card UID Input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: TextFormField(
                      controller: _uidController,
                      style: const TextStyle(color: Color(0xFF1F2232), fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Mã Thẻ Học Sinh (e.g. 04E2D3B2)',
                        hintStyle: TextStyle(color: const Color(0xFF2D3142).withOpacity(0.4), fontSize: 14, fontWeight: FontWeight.normal),
                        prefixIcon: const Icon(Icons.badge_rounded, color: Color(0xFF6C63FF)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Vui lòng nhập mã thẻ học sinh';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Parent Name Input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: TextFormField(
                      controller: _parentNameController,
                      style: const TextStyle(color: Color(0xFF1F2232), fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Họ và tên Phụ huynh',
                        hintStyle: TextStyle(color: const Color(0xFF2D3142).withOpacity(0.4), fontSize: 14, fontWeight: FontWeight.normal),
                        prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF6C63FF)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Vui lòng nhập họ và tên phụ huynh';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // New Password Input
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
                        hintText: 'Mật khẩu mới',
                        hintStyle: TextStyle(color: const Color(0xFF2D3142).withOpacity(0.4), fontSize: 14, fontWeight: FontWeight.normal),
                        prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF6C63FF)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                      validator: (val) {
                        if (val == null || val.length < 6) return 'Mật khẩu phải dài ít nhất 6 ký tự';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password Input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Color(0xFF1F2232), fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Xác nhận mật khẩu mới',
                        hintStyle: TextStyle(color: const Color(0xFF2D3142).withOpacity(0.4), fontSize: 14, fontWeight: FontWeight.normal),
                        prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF6C63FF)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                      validator: (val) {
                        if (val != _passwordController.text) return 'Mật khẩu xác nhận không trùng khớp';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Submit Button
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSetup,
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
                              'Kích Hoạt Tài Khoản',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
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
