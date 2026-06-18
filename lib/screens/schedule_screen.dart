import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/api_service.dart';

class ScheduleScreen extends StatefulWidget {
  final String lop;
  final String role; // 'parent' or 'teacher'

  const ScheduleScreen({super.key, required this.lop, required this.role});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _isLoading = true;
  String? _error;
  Map<int, Map<String, int>> _weekSchedule = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchSchedule();
  }

  Future<void> _fetchSchedule() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await apiService.getWeekSchedule(widget.lop, '');
      if (res.data != null && res.data['week'] != null) {
        final rawWeek = res.data['week'] as Map;
        final Map<int, Map<String, int>> parsedWeek = {};
        rawWeek.forEach((key, val) {
          final int day = int.parse(key.toString());
          final Map<String, int> sessions = {};
          (val as Map).forEach((sKey, sVal) {
            sessions[sKey.toString()] = int.parse(sVal.toString());
          });
          parsedWeek[day] = sessions;
        });

        setState(() {
          _weekSchedule = parsedWeek;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Dữ liệu thời khóa biểu trống';
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
        _error = 'Đã xảy ra lỗi tải thời khóa biểu';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSchedule() async {
    if (widget.role != 'teacher') return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Structure week schedule payload
      final weekPayload = <String, Map<String, int>>{};
      _weekSchedule.forEach((key, value) {
        weekPayload[key.toString()] = value;
      });

      await apiService.setWeekSchedule(widget.lop, weekPayload);
      if (!mounted) return;
      Fluttertoast.showToast(msg: 'Lưu thời khóa biểu thành công', backgroundColor: Colors.green);
    } on DioException catch (e) {
      String errMsg = 'Lỗi lưu dữ liệu';
      if (e.response != null && e.response!.data != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('detail')) {
          errMsg = data['detail'].toString();
        }
      }
      if (!mounted) return;
      Fluttertoast.showToast(msg: '⚠️ $errMsg', backgroundColor: Colors.orange);
    } catch (_) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: '⚠️ Lỗi không xác định', backgroundColor: Colors.red);
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // Extensions or helper extensions in apiService could be updated to support setWeekSchedule.
  // Wait, does apiService have setWeekSchedule? Let's check api_service.dart if it has put setWeekSchedule.
  // Oh! We need to add it if it's missing. Let's add it dynamically or build a wrapper inside the screen.
  // It's cleaner to add it to ApiService, but for now we can just use the direct _dio call if needed,
  // or we can use ApiService since we will add it there! Let's make sure it is added.

  @override
  Widget build(BuildContext context) {
    final isTeacher = widget.role == 'teacher';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2D3142)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'TKB Lớp ${widget.lop}',
          style: const TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isTeacher && !_isLoading && _error == null)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.save_rounded, color: Color(0xFF6C63FF), size: 28),
                      onPressed: _saveSchedule,
                    ),
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _fetchSchedule,
                          child: const Text('Thử lại'),
                        )
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: 6, // Thứ 2 -> Thứ 7
                  itemBuilder: (context, index) {
                    final day = index + 2;
                    final sang = _weekSchedule[day]?['sang'] ?? 1;
                    final chieu = _weekSchedule[day]?['chieu'] ?? 1;

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
                          // Day name badge
                          Container(
                            width: 60,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0EFFF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'T$day',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6C63FF),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),

                          // Sáng / Chiều Switchers
                          Expanded(
                            child: Column(
                              children: [
                                _buildSessionRow(
                                  sessionName: 'Buổi sáng',
                                  isActive: sang == 1,
                                  isTeacher: isTeacher,
                                  onChanged: (val) {
                                    setState(() {
                                      _weekSchedule[day]?['sang'] = val ? 1 : 0;
                                    });
                                  },
                                ),
                                const Divider(height: 16),
                                _buildSessionRow(
                                  sessionName: 'Buổi chiều',
                                  isActive: chieu == 1,
                                  isTeacher: isTeacher,
                                  onChanged: (val) {
                                    setState(() {
                                      _weekSchedule[day]?['chieu'] = val ? 1 : 0;
                                    });
                                  },
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildSessionRow({
    required String sessionName,
    required bool isActive,
    required bool isTeacher,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          sessionName,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
        ),
        isTeacher
            ? Switch(
                value: isActive,
                onChanged: onChanged,
                activeThumbColor: const Color(0xFF6C63FF),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFEFFFFA) : const Color(0xFFFFECEC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isActive ? 'Học' : 'Nghỉ',
                  style: TextStyle(
                    color: isActive ? const Color(0xFF20C997) : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
      ],
    );
  }
}
