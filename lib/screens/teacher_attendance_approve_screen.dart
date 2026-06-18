import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:fluttertoast/fluttertoast.dart';

class TeacherAttendanceApproveScreen extends StatefulWidget {
  final dynamic user;

  const TeacherAttendanceApproveScreen({super.key, required this.user});

  @override
  State<TeacherAttendanceApproveScreen> createState() => _TeacherAttendanceApproveScreenState();
}

class _TeacherAttendanceApproveScreenState extends State<TeacherAttendanceApproveScreen> {
  List<dynamic> _pauseList = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPauses();
  }

  Future<void> _fetchPauses() async {
    try {
      final res = await apiService.getPauseAttendance(widget.user.username);
      if (res.data != null && res.data['items'] != null) {
        setState(() {
          _pauseList = res.data['items'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Không thể lấy danh sách tạm dừng';
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

  Future<void> _deletePause(int id) async {
    try {
      final res = await apiService.deletePauseAttendance(id, widget.user.username);
      if (res.statusCode == 200) {
        if (!mounted) return;
        Fluttertoast.showToast(msg: 'Xóa lịch tạm dừng thành công', backgroundColor: Colors.green);
        _fetchPauses();
      }
    } catch (_) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: 'Không thể xóa. Vui lòng thử lại.', backgroundColor: Colors.red);
    }
  }

  void _showAddPauseDialog() {
    final tuNgayController = TextEditingController(
      text: DateTime.now().toIso8601String().split('T')[0],
    );
    final denNgayController = TextEditingController();
    final lyDoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text(
            'Tạm Dừng Điểm Danh',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2232)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tuNgayController,
                  decoration: InputDecoration(
                    labelText: 'Từ ngày (YYYY-MM-DD)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6C63FF)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: denNgayController,
                  decoration: InputDecoration(
                    labelText: 'Đến ngày (Tùy chọn)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6C63FF)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: lyDoController,
                  decoration: InputDecoration(
                    labelText: 'Lý do',
                    labelStyle: const TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6C63FF)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('HỦY', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (tuNgayController.text.isEmpty || lyDoController.text.isEmpty) {
                  Fluttertoast.showToast(msg: 'Vui lòng nhập đầy đủ thông tin', backgroundColor: Colors.orange);
                  return;
                }
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  await apiService.createPauseAttendance(
                    tuNgay: tuNgayController.text.trim(),
                    denNgay: denNgayController.text.trim().isEmpty ? '' : denNgayController.text.trim(),
                    lyDo: lyDoController.text.trim(),
                    username: widget.user.username,
                  );
                  _fetchPauses();
                } catch (_) {
                  setState(() => _isLoading = false);
                  if (!context.mounted) return;
                  Fluttertoast.showToast(msg: 'Không thể tạo lịch tạm dừng', backgroundColor: Colors.red);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('THIẾT LẬP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
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
          'Duyệt / Tạm Dừng Điểm Danh',
          style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPauseDialog,
        backgroundColor: const Color(0xFF6C63FF),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _pauseList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_available_rounded, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Không có lịch tạm dừng nào',
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      itemCount: _pauseList.length,
                      itemBuilder: (context, index) {
                        final pause = _pauseList[index];
                        final tuNgay = pause['tu_ngay'] ?? '';
                        final denNgay = pause['den_ngay'] ?? 'Không xác định';
                        final lyDo = pause['ly_do'] ?? 'Không có lý do';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lyDo,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1F2232),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Từ ngày: $tuNgay',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Đến ngày: $denNgay',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF6B6B)),
                                onPressed: () => _deletePause(pause['id']),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
