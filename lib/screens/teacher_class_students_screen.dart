import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';

class TeacherClassStudentsScreen extends StatefulWidget {
  final dynamic user;

  const TeacherClassStudentsScreen({super.key, required this.user});

  @override
  State<TeacherClassStudentsScreen> createState() => _TeacherClassStudentsScreenState();
}

class _TeacherClassStudentsScreenState extends State<TeacherClassStudentsScreen> {
  List<dynamic> _studentList = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    final lop = widget.user.lopQuyen;
    if (lop == null || lop.isEmpty) {
      setState(() {
        _error = 'Tài khoản chưa được gán quyền lớp chủ nhiệm';
        _isLoading = false;
      });
      return;
    }

    try {
      final res = await apiService.getStudentsByClass(lop, widget.user.username);
      if (res.data != null && res.data['students'] != null) {
        setState(() {
          _studentList = res.data['students'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Không thể lấy danh sách học sinh';
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
          'Danh Sách Lớp $lop',
          style: const TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _studentList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Lớp học chưa có học sinh',
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      itemCount: _studentList.length,
                      itemBuilder: (context, index) {
                        final student = _studentList[index];
                        final name = student['ten'] ?? 'Không tên';
                        final uid = student['uid_the'] ?? 'Không có UID';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
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
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () => _showStudentDetail(context, student),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF20C997).withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                        image: student['anh_the'] != null && student['anh_the'].toString().isNotEmpty
                                            ? DecorationImage(
                                                image: CachedNetworkImageProvider(student['anh_the']),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: (student['anh_the'] == null || student['anh_the'].toString().isEmpty)
                                          ? const Icon(Icons.person_rounded, color: Color(0xFF20C997), size: 28)
                                          : null,
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2D3142),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Mã thẻ: $uid',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF4F7FC),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Chi tiết',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  void _showStudentDetail(BuildContext context, dynamic student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF20C997).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  image: student['anh_the'] != null && student['anh_the'].toString().isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(student['anh_the']),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (student['anh_the'] == null || student['anh_the'].toString().isEmpty)
                    ? const Icon(Icons.person_rounded, color: Color(0xFF20C997), size: 50)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                student['ten'] ?? 'Không tên',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2232)),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Lớp: ${student['lop'] ?? 'Chưa có'}',
                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 32),
              _buildDetailRow('Mã thẻ (UID)', student['uid_the'] ?? 'Chưa có', Icons.badge_outlined),
              const Divider(height: 24),
              _buildDetailRow('Giới tính', student['gioi_tinh'] ?? 'Chưa có', Icons.wc_outlined),
              const Divider(height: 24),
              _buildDetailRow('Ngày sinh', _formatDate(student['ngay_sinh']), Icons.cake_outlined),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    elevation: 0,
                  ),
                  child: const Text('Đóng', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(dynamic dateString) {
    if (dateString == null || dateString.toString().isEmpty) return 'Chưa có';
    try {
      final date = DateTime.parse(dateString.toString());
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    } catch (e) {
      // If it's not a valid ISO string, just return it directly (maybe it's already formatted)
      return dateString.toString();
    }
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[500], size: 24),
        const SizedBox(width: 16),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Color(0xFF1F2232), fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
