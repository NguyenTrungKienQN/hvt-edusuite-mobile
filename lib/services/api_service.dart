import 'package:dio/dio.dart';

class ApiService {
  // Replace with your local server IP (e.g. 'http://192.168.1.100:8000') or domain name
  static const String defaultBaseUrl = 'https://hvtapi.io.vn'; // Public backend domain
  
  final Dio _dio;
  String _baseUrl = defaultBaseUrl;

  ApiService() : _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10))) {
    _dio.options.baseUrl = _baseUrl;
    _dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        if (response.data is Map && response.data.containsKey('data')) {
          response.data = response.data['data'];
        }
        return handler.next(response);
      },
    ));
  }

  void setBaseUrl(String newUrl) {
    _baseUrl = newUrl;
    _dio.options.baseUrl = newUrl;
  }

  String get baseUrl => _baseUrl;

  void setToken(String? token) {
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  // 1. Mobile Login API
  Future<Response> login({
    required String role,
    required String identifier,
    required String password,
  }) async {
    return await _dio.post('/api/v1/auth/mobile/login', data: {
      'role': role,
      'identifier': identifier,
      'password': password,
    });
  }

  // 2. Setup Parent Password
  Future<Response> setupParentPassword({
    required String uidThe,
    required String newPassword,
    String? tenPhuHuynh,
  }) async {
    return await _dio.post('/api/v1/auth/setup-password', data: {
      'uid_the': uidThe,
      'new_password': newPassword,
      'ten_phu_huynh': tenPhuHuynh,
    });
  }

  // 3. Change Password
  Future<Response> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    return await _dio.post(
      '/api/v1/auth/change-password',
      data: {
        'old_password': oldPassword,
        'new_password': newPassword,
      },
    );
  }

  // 4. Get Current Profile (Me)
  Future<Response> getProfile() async {
    return await _dio.get('/api/v1/auth/me');
  }

  // 5. Get Student Attendance History (Parent)
  Future<Response> getStudentAttendance(String uidThe) async {
    return await _dio.get('/api/v1/students/$uidThe/attendance');
  }

  // 6. Get Class Weekly Schedule (Parent/Teacher)
  Future<Response> getWeekSchedule(String lop, String username) async {
    return await _dio.get('/api/v1/schedule/$lop/week');
  }

  // Update Class Weekly Schedule (Teacher)
  Future<Response> setWeekSchedule(String lop, Map<String, Map<String, int>> week) async {
    return await _dio.put(
      '/api/v1/schedule/$lop/week',
      data: {
        'hieu_luc_tu': DateTime.now().toIso8601String().substring(0, 10),
        'week': week,
      },
    );
  }

  // 7. Get Class Attendance Today (Teacher)
  Future<Response> getAttendanceToday(String lop, String buoi, String username) async {
    return await _dio.get(
      '/api/v1/classes/$lop/attendance',
      queryParameters: {'buoi': buoi},
    );
  }

  // 8. Get Class Students List (Teacher)
  Future<Response> getStudentsByClass(String lop, {String? username}) async {
    return await _dio.get('/api/v1/classes/$lop/mobile-students');
  }

  // 8.1. Get Homeroom Teacher
  Future<Response> getHomeroomTeacher(String lop) async {
    return await _dio.get('/api/v1/classes/$lop/homeroom');
  }

  // 8.2. Get Student Detail
  Future<Response> getStudentDetail(String uid) async {
    return await _dio.get('/api/v1/students/$uid');
  }

  // 9. Get Attendance Pause History (Teacher)
  Future<Response> getPauseAttendance(String username) async {
    return await _dio.get('/api/v1/attendance/pauses');
  }

  // 10. Create Attendance Pause (Teacher)
  Future<Response> createPauseAttendance({
    required String tuNgay,
    required String denNgay,
    required String lyDo,
    required String username,
  }) async {
    return await _dio.post(
      '/api/v1/attendance/pauses',
      data: {
        'tu_ngay': tuNgay,
        'den_ngay': denNgay,
        'ly_do': lyDo,
      },
    );
  }

  // 11. Delete Attendance Pause (Teacher)
  Future<Response> deletePauseAttendance(int pauseId, String username) async {
    return await _dio.delete('/api/v1/attendance/pauses/$pauseId');
  }

  // 12. Send message to AI Chat Assistant
  Future<Response> sendChatMessage(String message, List<Map<String, String>> history) async {
    return await _dio.post(
      '/api/v1/ai/chat',
      data: {
        'message': message,
        'history': history,
      },
    );
  }

  // 13. Create Telegram GVCN Link Code (Teacher)
  Future<Response> createTelegramLinkCode(String lop) async {
    return await _dio.post(
      '/api/v1/telegram/gvcn/create_code',
      queryParameters: {'lop': lop},
    );
  }

  // 14. Register FCM Token (Parent/Teacher)
  Future<Response> registerFCMToken(String token, String deviceType) async {
    return await _dio.post(
      '/api/v1/auth/fcm-token',
      data: {
        'token': token,
        'device_type': deviceType,
      },
    );
  }

  // 15. Update Parent Name (Parent)
  Future<Response> updateParentName(String tenPhuHuynh) async {
    return await _dio.put(
      '/api/v1/auth/parent-name',
      data: {
        'ten_phu_huynh': tenPhuHuynh,
      },
    );
  }

  // --- EVENTS API ---

  // Get all classes
  Future<Response> getClasses() async {
    return await _dio.get('/api/v1/classes');
  }

  // Get all students (Global Admin & Pagination support)
  Future<Response> getStudents({int page = 1, int pageSize = 50, String? lop, String? q}) async {
    Map<String, dynamic> params = {
      'page': page,
      'page_size': pageSize,
    };
    if (lop != null && lop.isNotEmpty) params['lop'] = lop;
    if (q != null && q.isNotEmpty) params['q'] = q;
    return await _dio.get('/api/v1/students', queryParameters: params);
  }

  // Get list of events (with optional filters)
  Future<Response> getEvents({String? lop, String? fromDate, String? toDate}) async {
    Map<String, dynamic> params = {};
    if (lop != null && lop.isNotEmpty) params['lop'] = lop;
    if (fromDate != null) params['from_date'] = fromDate;
    if (toDate != null) params['to_date'] = toDate;
    return await _dio.get('/api/v1/events', queryParameters: params);
  }

  // Get active events
  Future<Response> getActiveEvents() async {
    return await _dio.get('/api/v1/events/active');
  }

  // Get event details
  Future<Response> getEventDetail(int eventId) async {
    return await _dio.get('/api/v1/events/$eventId');
  }

  // Create event
  Future<Response> createEvent(Map<String, dynamic> eventData) async {
    return await _dio.post('/api/v1/events', data: eventData);
  }

  // Update event
  Future<Response> updateEvent(int eventId, Map<String, dynamic> eventData) async {
    return await _dio.put('/api/v1/events/$eventId', data: eventData);
  }

  // Delete event
  Future<Response> deleteEvent(int eventId) async {
    return await _dio.delete('/api/v1/events/$eventId');
  }

  // Scan attendance via UID
  Future<Response> scanEventAttendance(int eventId, String uidThe) async {
    return await _dio.post(
      '/api/v1/events/$eventId/scan',
      data: {'uid_the': uidThe},
    );
  }

  // Auto scan attendance
  Future<Response> autoScanEventAttendance() async {
    return await _dio.post('/api/v1/events/scan_auto');
  }

  // Get event attendance list
  Future<Response> getEventAttendance(int eventId) async {
    return await _dio.get('/api/v1/events/$eventId/attendance');
  }

  // Add event participants manually
  Future<Response> addEventParticipants(int eventId, List<String> uids) async {
    return await _dio.post(
      '/api/v1/events/$eventId/participants',
      data: uids,
    );
  }
}

// Single instance for global app usage
final apiService = ApiService();

// Make from Kiên and Dương with love
