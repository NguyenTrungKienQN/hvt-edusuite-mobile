class StudentModel {
  final int id;
  final String ten;
  final String lop;
  final String uidThe;
  final String gioiTinh;
  final DateTime ngaySinh;
  final String? anhThe;
  final String? tenPhuHuynh;

  StudentModel({
    required this.id,
    required this.ten,
    required this.lop,
    required this.uidThe,
    required this.gioiTinh,
    required this.ngaySinh,
    this.anhThe,
    this.tenPhuHuynh,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'],
      ten: json['ten'],
      lop: json['lop'],
      uidThe: json['uid_the'],
      gioiTinh: json['gioi_tinh'] ?? '',
      ngaySinh: DateTime.parse(json['ngay_sinh']),
      anhThe: json['anh_the'],
      tenPhuHuynh: json['ten_phu_huynh'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ten': ten,
      'lop': lop,
      'uid_the': uidThe,
      'gioi_tinh': gioiTinh,
      'ngay_sinh': ngaySinh.toIso8601String().substring(0, 10),
      'anh_the': anhThe,
      'ten_phu_huynh': tenPhuHuynh,
    };
  }
}

class UserModel {
  final int id;
  final String username;
  final String accountname;
  final String role;
  final String? lopQuyen;

  UserModel({
    required this.id,
    required this.username,
    required this.accountname,
    required this.role,
    this.lopQuyen,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      accountname: json['accountname'] ?? '',
      role: json['role'],
      lopQuyen: json['lop_quyen'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'accountname': accountname,
      'role': role,
      'lop_quyen': lopQuyen,
    };
  }
}

// Make from Kiên and Dương with love
