import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('saved_notifications');
    if (data != null) {
      try {
        final List<dynamic> parsed = jsonDecode(data);
        _notifications = List<Map<String, dynamic>>.from(parsed);
        // Sort by timestamp descending (newest first)
        _notifications.sort((a, b) {
          final timeA = a['timestamp'] ?? 0;
          final timeB = b['timestamp'] ?? 0;
          return (timeB as int).compareTo(timeA as int);
        });
      } catch (e) {
        _notifications = [];
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearNotifications() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tất cả?'),
        content: const Text('Bạn có chắc chắn muốn xóa toàn bộ thông báo không? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_notifications');
      setState(() {
        _notifications = [];
      });
    }
  }

  String _formatTimestamp(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} - ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Thông báo',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF1F2232)),
                  ),
                  if (_notifications.isNotEmpty)
                    TextButton.icon(
                      onPressed: _clearNotifications,
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF6B6B)),
                      label: const Text('Xóa tất cả', style: TextStyle(color: Color(0xFFFF6B6B))),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                  : _notifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_off_rounded, size: 80, color: Colors.grey.withValues(alpha: 0.3)),
                              const SizedBox(height: 16),
                              const Text(
                                'Không có thông báo nào',
                                style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadNotifications,
                          color: const Color(0xFF6C63FF),
                          child: ListView.separated(
                            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 8),
                            itemCount: _notifications.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final notif = _notifications[index];
                              final title = notif['title'] ?? 'Thông báo';
                              final body = notif['body'] ?? '';
                              final timestamp = notif['timestamp'] as int?;
                              
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF6C63FF), size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      body,
                                      style: TextStyle(fontSize: 14, color: const Color(0xFF2D3142).withValues(alpha: 0.8), height: 1.5),
                                    ),
                                    if (timestamp != null) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        _formatTimestamp(timestamp),
                                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                                      ),
                                    ]
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// Make from Kiên and Dương with love
