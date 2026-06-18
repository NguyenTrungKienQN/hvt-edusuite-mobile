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
  Future<Response> getStudentsByClass(String lop, String username) async {
    return await _dio.get('/api/v1/classes/$lop/mobile-students');
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
}

// Single instance for global app usage
final apiService = ApiService();
