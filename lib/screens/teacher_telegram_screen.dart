import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:async';

class TeacherTelegramScreen extends StatefulWidget {
  final dynamic user;

  const TeacherTelegramScreen({super.key, required this.user});

  @override
  State<TeacherTelegramScreen> createState() => _TeacherTelegramScreenState();
}

class _TeacherTelegramScreenState extends State<TeacherTelegramScreen> {
  String? _code;
  DateTime? _expiresAt;
  bool _isLoading = false;
  String? _error;
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _generateCode() async {
    final lop = widget.user.lopQuyen;
    if (lop == null || lop.isEmpty) {
      setState(() {
        _error = 'Tài khoản chưa được gán quyền lớp chủ nhiệm';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _code = null;
    });

    try {
      final res = await apiService.createTelegramLinkCode(lop);
      if (res.data != null && res.data['code'] != null) {
        final code = res.data['code'];
        final expiresStr = res.data['expires_at'];
        final expires = DateTime.parse(expiresStr);

        setState(() {
          _code = code;
          _expiresAt = expires;
          _isLoading = false;
          _timeLeft = expires.difference(DateTime.now());
        });

        _startTimer();
      } else {
        setState(() {
          _error = 'Không thể tạo mã liên kết';
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      String errMsg = 'Lỗi kết nối máy chủ';
      if (e.response != null && e.response!.data != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('detail')) {
          errMsg = data['detail'].toString();
        }
      }
      setState(() {
        _error = errMsg;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Đã xảy ra lỗi không mong muốn';
        _isLoading = false;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_expiresAt == null) {
        timer.cancel();
        return;
      }
      final diff = _expiresAt!.difference(DateTime.now());
      if (diff.isNegative) {
        setState(() {
          _code = null;
          _timeLeft = Duration.zero;
        });
        timer.cancel();
      } else {
        setState(() {
          _timeLeft = diff;
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final lop = widget.user.lopQuyen ?? 'N/A';
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2D3142)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Liên Kết Telegram GVCN',
          style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bot Info Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0088CC), // Telegram Blue
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nhận Thông Báo Qua Telegram',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2232)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Liên kết tài khoản Telegram để nhận thông báo tức thời khi học sinh lớp $lop quẹt thẻ điểm danh.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: const Color(0xFF2D3142).withValues(alpha: 0.6), fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Instructions Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hướng dẫn liên kết:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2232)),
                  ),
                  const SizedBox(height: 16),
                  _buildStepRow(1, 'Mở ứng dụng Telegram và tìm bot: @hvt_edusuite_bot (hoặc nhấn nút bên dưới).'),
                  const SizedBox(height: 12),
                  _buildStepRow(2, 'Nhấn nút Gửi Mã bên dưới để tạo mã xác thực 10 phút.'),
                  const SizedBox(height: 12),
                  _buildStepRow(3, 'Gửi lệnh sau tới Telegram Bot:\n/link <MÃ_CỦA_BẠN>'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),

            if (_code != null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFFFFA),
                  border: Border.all(color: const Color(0xFF20C997), width: 1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Text(
                      'MÃ XÁC THỰC CỦA BẠN:',
                      style: TextStyle(color: Color(0xFF20C997), fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _code!));
                        Fluttertoast.showToast(msg: 'Đã sao chép mã liên kết', backgroundColor: Colors.green);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _code!,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              color: Color(0xFF1F2232),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.copy_rounded, color: Colors.grey, size: 24),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.grey, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Mã sẽ hết hạn trong: ${_formatDuration(_timeLeft)}',
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _generateCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                    )
                  : Text(
                      _code != null ? 'Tạo Mã Mới' : 'Tạo Mã Liên Kết',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow(int step, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFF6C63FF),
            shape: BoxShape.circle,
          ),
          child: Text(
            step.toString(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF2D3142), fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }
}
