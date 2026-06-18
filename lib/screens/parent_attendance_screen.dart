import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ParentAttendanceScreen extends StatefulWidget {
  final dynamic student;

  const ParentAttendanceScreen({super.key, required this.student});

  @override
  State<ParentAttendanceScreen> createState() => _ParentAttendanceScreenState();
}

class _ParentAttendanceScreenState extends State<ParentAttendanceScreen> {
  List<dynamic> _attendanceList = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    try {
      final res = await apiService.getStudentAttendance(widget.student.uidThe);
      if (res.data != null && res.data['attendance'] != null) {
        setState(() {
          _attendanceList = res.data['attendance'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Không thể lấy dữ liệu điểm danh';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Lỗi kết nối máy chủ';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Lịch Sử Điểm Danh',
          style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _attendanceList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa có dữ liệu điểm danh',
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      itemCount: _attendanceList.length,
                      itemBuilder: (context, index) {
                        final record = _attendanceList[index];
                        final rawTime = record['thoi_gian'] ?? '';
                        String displayDate = 'Không rõ';
                        String displayTime = '';
                        if (rawTime.isNotEmpty) {
                          try {
                            final parsed = DateTime.parse(rawTime);
                            displayDate = '${parsed.day}/${parsed.month}/${parsed.year}';
                            displayTime = '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
                          } catch (_) {}
                        }

                        final status = record['trang_thai'] ?? 'Vắng';
                        final isLate = status == 'Đi học muộn';
                        final isAbsent = status == 'Vắng';

                        Color accentColor = const Color(0xFF20C997); // green
                        Color bgColor = const Color(0xFFE8F9F4);
                        IconData statusIcon = Icons.check_circle_rounded;

                        if (isLate) {
                          accentColor = const Color(0xFFFF9F43); // orange
                          bgColor = const Color(0xFFFFF5EC);
                          statusIcon = Icons.watch_later_rounded;
                        } else if (isAbsent) {
                          accentColor = const Color(0xFFFF6B6B); // red
                          bgColor = const Color(0xFFFFECEC);
                          statusIcon = Icons.cancel_rounded;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(statusIcon, color: accentColor, size: 28),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      status + (isLate ? ' (${record['muon_phut']} phút)' : ''),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isAbsent ? const Color(0xFFFF6B6B) : const Color(0xFF2D3142),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Buổi: ${record['buoi'] == 'sang' ? 'Sáng' : 'Chiều'}',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    displayDate,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  if (displayTime.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      displayTime,
                                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                    ),
                                  ],
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
