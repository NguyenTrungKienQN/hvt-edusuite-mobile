import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/event_model.dart';
import '../services/api_service.dart';

class EventAttendanceScreen extends StatefulWidget {
  final EventModel event;

  const EventAttendanceScreen({super.key, required this.event});

  @override
  State<EventAttendanceScreen> createState() => _EventAttendanceScreenState();
}

class _EventAttendanceScreenState extends State<EventAttendanceScreen> {
  bool _isLoading = true;
  List<EventAttendanceModel> _attendanceList = [];

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchAttendance() async {
    setState(() => _isLoading = true);
    try {
      final res = await apiService.getEventAttendance(widget.event.id);
      if (res.statusCode == 200 && res.data != null) {
        final List<dynamic> data = res.data is List ? res.data : (res.data['data'] ?? []);
        setState(() {
          _attendanceList = data.map((e) => EventAttendanceModel.fromJson(e)).toList();
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi tải danh sách điểm danh", backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat timeFormat = DateFormat('HH:mm dd/MM/yyyy');
    final DateFormat scanFormat = DateFormat('HH:mm:ss');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text(
          'Điểm danh Sự kiện',
          style: TextStyle(color: Color(0xFF1F2232), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F2232)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchAttendance,
          ),
        ],
      ),
      body: Column(
        children: [
          // Event Info
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEEECFF), Color(0xFFF6F8FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.event.ten,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2232)),
                ),
                const SizedBox(height: 8),
                Text('Thời gian: ${timeFormat.format(widget.event.batDau)} - ${timeFormat.format(widget.event.ketThuc)}'),
                if (widget.event.lop != null && widget.event.lop!.isNotEmpty)
                  Text('Lớp: ${widget.event.lop}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          const Divider(),

          // Attendance List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : _attendanceList.isEmpty
                    ? const Center(child: Text("Chưa có dữ liệu điểm danh"))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _attendanceList.length,
                        itemBuilder: (context, index) {
                          final att = _attendanceList[index];
                          final isLate = att.trangThai == 'DiMuon';
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isLate ? Colors.orange.shade100 : Colors.green.shade100,
                                child: Icon(
                                  isLate ? Icons.timer_rounded : Icons.check_circle_rounded,
                                  color: isLate ? Colors.orange : Colors.green,
                                ),
                              ),
                              title: Text(att.tenHocSinh ?? att.uidThe, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("Thời gian: ${scanFormat.format(att.thoiGianScan)}"),
                              trailing: Text(
                                isLate ? "Đi muộn" : "Đúng giờ",
                                style: TextStyle(
                                  color: isLate ? Colors.orange : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// Make from Kiên and Dương with love
