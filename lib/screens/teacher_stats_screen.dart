import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TeacherStatsScreen extends StatefulWidget {
  final dynamic user;

  const TeacherStatsScreen({super.key, required this.user});

  @override
  State<TeacherStatsScreen> createState() => _TeacherStatsScreenState();
}

class _TeacherStatsScreenState extends State<TeacherStatsScreen> {
  String _selectedBuoi = 'sang';
  List<dynamic> _records = [];
  bool _isLoading = true;
  String? _error;

  int _presentCount = 0;
  int _lateCount = 0;
  int _absentCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final lop = widget.user.lopQuyen;
    if (lop == null || lop.isEmpty) {
      setState(() {
        _error = 'Tài khoản chưa được gán quyền lớp chủ nhiệm';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await apiService.getAttendanceToday(lop, _selectedBuoi, widget.user.username);
      if (res.data != null && res.data['records'] != null) {
        final recordsList = res.data['records'] as List<dynamic>;
        
        int present = 0;
        int late = 0;
        int absent = 0;

        for (var r in recordsList) {
          final status = r['trang_thai'] ?? 'Vắng';
          if (status == 'Có mặt') {
            present++;
          } else if (status == 'Đi học muộn') {
            late++;
          } else {
            absent++;
          }
        }

        setState(() {
          _records = recordsList;
          _presentCount = present;
          _lateCount = late;
          _absentCount = absent;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Không thể lấy dữ liệu thống kê';
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
        title: Text(
          'Thống Kê Điểm Danh Lớp $lop',
          style: const TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Segmented Control for Sáng / Chiều
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (_selectedBuoi != 'sang') {
                          setState(() => _selectedBuoi = 'sang');
                          _fetchStats();
                        }
                      },
                      borderRadius: BorderRadius.circular(21),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _selectedBuoi == 'sang' ? const Color(0xFF6C63FF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(21),
                        ),
                        child: Text(
                          'Buổi Sáng',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _selectedBuoi == 'sang' ? Colors.white : const Color(0xFF2D3142).withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (_selectedBuoi != 'chieu') {
                          setState(() => _selectedBuoi = 'chieu');
                          _fetchStats();
                        }
                      },
                      borderRadius: BorderRadius.circular(21),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _selectedBuoi == 'chieu' ? const Color(0xFF6C63FF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(21),
                        ),
                        child: Text(
                          'Buổi Chiều',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _selectedBuoi == 'chieu' ? Colors.white : const Color(0xFF2D3142).withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
          else ...[
            // Counter Overview Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Expanded(child: _buildCountCard('Có mặt', _presentCount, const Color(0xFF20C997), const Color(0xFFE8F9F4))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCountCard('Đi muộn', _lateCount, const Color(0xFFFF9F43), const Color(0xFFFFF5EC))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCountCard('Vắng', _absentCount, const Color(0xFFFF6B6B), const Color(0xFFFFECEC))),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Student List Detail
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _records.length,
                itemBuilder: (context, index) {
                  final r = _records[index];
                  final name = r['ten'] ?? 'Không tên';
                  final status = r['trang_thai'] ?? 'Vắng';
                  final time = r['thoi_gian'] ?? '';
                  final isLate = status == 'Đi học muộn';
                  final isAbsent = status == 'Vắng';

                  Color accentColor = const Color(0xFF20C997);
                  Color bgColor = const Color(0xFFE8F9F4);
                  if (isLate) {
                    accentColor = const Color(0xFFFF9F43);
                    bgColor = const Color(0xFFFFF5EC);
                  } else if (isAbsent) {
                    accentColor = const Color(0xFFFF6B6B);
                    bgColor = const Color(0xFFFFECEC);
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                        ),
                        Row(
                          children: [
                            if (time.isNotEmpty) ...[
                              Text(
                                time,
                                style: TextStyle(color: Colors.grey[500], fontSize: 13),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                status + (isLate ? ' (${r['muon_phut']}\')' : ''),
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  );
                },
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildCountCard(String title, int count, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(
              title == 'Có mặt'
                  ? Icons.check_rounded
                  : title == 'Đi muộn'
                      ? Icons.watch_later_rounded
                      : Icons.close_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1F2232)),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
          )
        ],
      ),
    );
  }
}
