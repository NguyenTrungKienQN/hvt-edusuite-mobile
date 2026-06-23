import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'teacher_class_students_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ClassesScreen extends StatefulWidget {
  final dynamic user;

  const ClassesScreen({super.key, required this.user});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  bool _isLoading = true;
  final List<String> _classes10 = [];
  final List<String> _classes11 = [];
  final List<String> _classes12 = [];

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    // If teacher, they only see their homeroom class. We shouldn't really be here based on the new logic, but fallback just in case.
    if (widget.user.role != 'admin') {
      final lop = widget.user.lopQuyen;
      if (lop != null && lop.isNotEmpty) {
        if (lop.startsWith('10')) {
          _classes10.add(lop);
        } else if (lop.startsWith('11')) {
          _classes11.add(lop);
        } else if (lop.startsWith('12')) {
          _classes12.add(lop);
        }
      }
      setState(() => _isLoading = false);
      return;
    }

    // If Admin, fetch all classes
    try {
      final res = await apiService.getClasses();
      if (res.statusCode == 200 && res.data != null) {
        final List<dynamic> classList = res.data['classes'] ?? [];
        for (var c in classList) {
          final className = c.toString();
          if (className.startsWith('10')) {
            _classes10.add(className);
          } else if (className.startsWith('11')) {
            _classes11.add(className);
          } else if (className.startsWith('12')) {
            _classes12.add(className);
          }
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi tải danh sách lớp", backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToClass(String lop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherClassStudentsScreen(user: widget.user, lop: lop),
      ),
    );
  }

  Widget _buildClassGroup(String title, List<String> classes, Color color) {
    if (classes.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
          ),
        ),
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
          ),
          itemCount: classes.length,
          itemBuilder: (context, index) {
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _navigateToClass(classes[index]),
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  classes[index],
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Danh Sách Lớp Học', style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D3142)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : (_classes10.isEmpty && _classes11.isEmpty && _classes12.isEmpty)
              ? const Center(child: Text('Không có lớp học nào', style: TextStyle(color: Colors.grey)))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      if (widget.user.role == 'admin')
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: Color(0xFF6C63FF)),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Chế độ Ban giám hiệu: Hiển thị toàn bộ lớp học trong trường.',
                                  style: TextStyle(color: Color(0xFF2D3142)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      _buildClassGroup('Khối 10', _classes10, const Color(0xFF6C63FF)),
                      _buildClassGroup('Khối 11', _classes11, const Color(0xFF20C997)),
                      _buildClassGroup('Khối 12', _classes12, const Color(0xFFFF9F43)),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }
}

// Make from Kiên and Dương with love
