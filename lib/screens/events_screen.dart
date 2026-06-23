import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/event_model.dart';
import '../services/api_service.dart';
import 'event_form_screen.dart';
import 'event_attendance_screen.dart';

class EventsScreen extends StatefulWidget {
  final String? lop;
  const EventsScreen({super.key, this.lop});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  bool _isLoading = true;
  List<EventModel> _events = [];

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() => _isLoading = true);
    try {
      if (widget.lop != null && widget.lop!.isNotEmpty) {
        // Fetch for specific class
        final res = await apiService.getEvents(lop: widget.lop);
        if (res.statusCode == 200 && res.data != null) {
          final List<dynamic> data = res.data is List ? res.data : (res.data['data'] ?? []);
          setState(() {
            _events = data.map((e) => EventModel.fromJson(e)).toList();
            _events.sort((a, b) => b.batDau.compareTo(a.batDau));
          });
        }
      } else {
        // Global Admin view: fetch all classes, then events for each
        final classesRes = await apiService.getClasses();
        if (classesRes.statusCode == 200 && classesRes.data != null) {
          final List<dynamic> classList = classesRes.data['classes'] ?? [];
          
          final eventFutures = classList.map((c) => apiService.getEvents(lop: c.toString()));
          final responses = await Future.wait(eventFutures);
          
          final Map<int, EventModel> uniqueEvents = {};
          
          for (var res in responses) {
            if (res.statusCode == 200 && res.data != null) {
              final List<dynamic> data = res.data is List ? res.data : (res.data['data'] ?? []);
              for (var e in data) {
                final model = EventModel.fromJson(e);
                uniqueEvents[model.id] = model;
              }
            }
          }
          
          setState(() {
            _events = uniqueEvents.values.toList();
            _events.sort((a, b) => b.batDau.compareTo(a.batDau));
          });
        }
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Lỗi khi tải danh sách sự kiện",
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEvent(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa sự kiện này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await apiService.deleteEvent(id);
      if (res.statusCode == 200 || res.statusCode == 204) {
        Fluttertoast.showToast(msg: "Đã xóa sự kiện");
        _fetchEvents();
      } else {
        Fluttertoast.showToast(msg: "Lỗi xóa sự kiện", backgroundColor: Colors.red);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi kết nối", backgroundColor: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text(
          'Quản lý Sự kiện',
          style: TextStyle(color: Color(0xFF1F2232), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F2232)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : _events.isEmpty
              ? const Center(
                  child: Text(
                    'Chưa có sự kiện nào',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    final DateFormat timeFormat = DateFormat('HH:mm dd/MM/yyyy');
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 2,
                      shadowColor: Colors.black12,
                      color: Colors.white,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventAttendanceScreen(event: event),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.event_rounded, color: Color(0xFF6C63FF)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.ten,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1F2232),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Bắt đầu: ${timeFormat.format(event.batDau)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: const Color(0xFF2D3142).withValues(alpha: 0.6),
                                      ),
                                    ),
                                    Text(
                                      'Kết thúc: ${timeFormat.format(event.ketThuc)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: const Color(0xFF2D3142).withValues(alpha: 0.6),
                                      ),
                                    ),
                                    if (event.lop != null && event.lop!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Lớp: ${event.lop}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF20C997),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EventFormScreen(event: event),
                                      ),
                                    ).then((_) => _fetchEvents());
                                  } else if (value == 'delete') {
                                    _deleteEvent(event.id);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                                        SizedBox(width: 8),
                                        Text('Chỉnh sửa'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                                        SizedBox(width: 8),
                                        Text('Xóa'),
                                      ],
                                    ),
                                  ),
                                ],
                                icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6C63FF),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EventFormScreen(),
            ),
          ).then((_) => _fetchEvents());
        },
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

// Make from Kiên and Dương with love
