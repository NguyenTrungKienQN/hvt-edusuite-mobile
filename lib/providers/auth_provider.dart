import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/user_models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final String? role;
  final StudentModel? student;
  final UserModel? user;
  final String? errorMessage;

  AuthState({
    required this.status,
    this.role,
    this.student,
    this.user,
    this.errorMessage,
  });

  factory AuthState.unknown() => AuthState(status: AuthStatus.unknown);
  factory AuthState.loading() => AuthState(status: AuthStatus.loading);
  
  factory AuthState.authenticated({
    required String role,
    StudentModel? student,
    UserModel? user,
  }) => AuthState(
    status: AuthStatus.authenticated,
    role: role,
    student: student,
    user: user,
  );

  factory AuthState.unauthenticated({String? error}) => AuthState(
    status: AuthStatus.unauthenticated,
    errorMessage: error,
  );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState.unknown()) {
    checkSession();
  }

  // 1. Check if token already exists to auto-login on startup
  Future<void> checkSession() async {
    state = AuthState.loading();
    final token = await authService.getToken();
    if (token == null) {
      state = AuthState.unauthenticated();
      return;
    }

    final isBioEnabled = await authService.isBiometricEnabled();
    if (isBioEnabled) {
      final success = await authService.authenticateWithBiometrics();
      if (!success) {
        state = AuthState.unauthenticated();
        return;
      }
    }

    try {
      final response = await apiService.getProfile();
      final data = response.data;
      if (data['role'] == 'parent') {
        state = AuthState.authenticated(
          role: 'parent',
          student: StudentModel.fromJson(data['student']),
        );
      } else {
        state = AuthState.authenticated(
          role: 'teacher',
          user: UserModel.fromJson(data['user']),
        );
      }
      NotificationService.instance.requestPermissionsAndRegisterToken();
    } catch (e) {
      // Token expired or server unreachable
      await authService.logout();
      state = AuthState.unauthenticated();
    }
  }

  // Reload session without setting loading state (for background updates)
  Future<void> reloadSessionSilently() async {
    try {
      final response = await apiService.getProfile();
      final data = response.data;
      if (data['role'] == 'parent') {
        state = AuthState.authenticated(
          role: 'parent',
          student: StudentModel.fromJson(data['student']),
        );
      } else {
        state = AuthState.authenticated(
          role: 'teacher',
          user: UserModel.fromJson(data['user']),
        );
      }
    } catch (e) {
      // Fail silently for background refreshes
    }
  }

  // 2. Perform regular credentials login
  Future<bool> login({
    required String role,
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await apiService.login(
        role: role,
        identifier: identifier,
        password: password,
      );
      
      final data = response.data;
      final token = data['access_token'];
      
      authService.sessionPassword = password;
      await authService.saveToken(token);
      await authService.saveCredentialsInfo(identifier, role);
      
      final bioEnabled = await authService.isBiometricEnabled();
      if (bioEnabled) {
        await authService.savePassword(password);
      }

      if (role == 'parent') {
        final student = StudentModel.fromJson(data['student']);
        state = AuthState.authenticated(role: 'parent', student: student);
      } else {
        final user = UserModel.fromJson(data['user']);
        state = AuthState.authenticated(role: 'teacher', user: user);
      }
      NotificationService.instance.requestPermissionsAndRegisterToken();
      return true;
    } on DioException catch (e) {
      String errMsg = 'Lỗi kết nối máy chủ';
      if (e.response != null && e.response!.data != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('detail')) {
          errMsg = data['detail'] ?? errMsg;
        }
      }
      state = AuthState.unauthenticated(error: errMsg);
      return false;
    } catch (e) {
      state = AuthState.unauthenticated(error: e.toString());
      return false;
    }
  }

  // 3. Quick Login with Biometrics
  Future<bool> loginWithBiometrics() async {
    final enabled = await authService.isBiometricEnabled();
    if (!enabled) {
      state = AuthState.unauthenticated(error: 'Vui lòng kích hoạt đăng nhập sinh trắc học trong phần cài đặt trước.');
      return false;
    }

    final credentials = await authService.getSavedCredentialsInfo();
    final savedId = credentials['identifier'];
    final savedRole = credentials['role'];
    final savedPassword = await authService.getSavedPassword();

    if (savedId == null || savedRole == null || savedPassword == null) {
      state = AuthState.unauthenticated(error: 'Không tìm thấy thông tin đăng nhập đã lưu. Vui lòng đăng nhập bằng mật khẩu trước.');
      return false;
    }

    final matched = await authService.authenticateWithBiometrics();
    if (!matched) return false;

    // Authenticate with saved credentials
    return await login(role: savedRole, identifier: savedId, password: savedPassword);
  }

  // 4. Logout Action
  Future<void> logout() async {
    await authService.logout();
    state = AuthState.unauthenticated();
  }

  // 5. Update Parent Name dynamically in state and database
  Future<bool> updateParentName(String name) async {
    try {
      final response = await apiService.updateParentName(name);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (state.student != null) {
          final updatedStudent = StudentModel(
            id: state.student!.id,
            ten: state.student!.ten,
            lop: state.student!.lop,
            uidThe: state.student!.uidThe,
            gioiTinh: state.student!.gioiTinh,
            ngaySinh: state.student!.ngaySinh,
            anhThe: state.student!.anhThe,
            tenPhuHuynh: name,
          );
          state = AuthState.authenticated(role: 'parent', student: updatedStudent);
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Update parent name locally in state (e.g. after successful DB update)
  void updateParentNameLocal(String name) {
    if (state.student != null) {
      final updatedStudent = StudentModel(
        id: state.student!.id,
        ten: state.student!.ten,
        lop: state.student!.lop,
        uidThe: state.student!.uidThe,
        gioiTinh: state.student!.gioiTinh,
        ngaySinh: state.student!.ngaySinh,
        anhThe: state.student!.anhThe,
        tenPhuHuynh: name,
      );
      state = AuthState.authenticated(role: 'parent', student: updatedStudent);
    }
  }
}

// Global provider for state consumption
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
