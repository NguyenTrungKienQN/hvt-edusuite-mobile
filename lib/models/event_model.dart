class EventModel {
  final int id;
  final String? lop;
  final String ten;
  final DateTime batDau;
  final DateTime ketThuc;
  final int muonSauPhut;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EventModel({
    required this.id,
    this.lop,
    required this.ten,
    required this.batDau,
    required this.ketThuc,
    required this.muonSauPhut,
    this.createdAt,
    this.updatedAt,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'],
      lop: json['lop'],
      ten: json['ten'],
      batDau: DateTime.parse(json['bat_dau']),
      ketThuc: DateTime.parse(json['ket_thuc']),
      muonSauPhut: json['muon_sau_phut'] ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lop': lop,
      'ten': ten,
      'bat_dau': batDau.toIso8601String(),
      'ket_thuc': ketThuc.toIso8601String(),
      'muon_sau_phut': muonSauPhut,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class EventAttendanceModel {
  final int id;
  final int eventId;
  final String uidThe;
  final String? tenHocSinh; // Might be joined by backend
  final DateTime thoiGianScan;
  final String trangThai; // e.g., 'DungGio', 'DiMuon', 'KhongHopLe'

  EventAttendanceModel({
    required this.id,
    required this.eventId,
    required this.uidThe,
    this.tenHocSinh,
    required this.thoiGianScan,
    required this.trangThai,
  });

  factory EventAttendanceModel.fromJson(Map<String, dynamic> json) {
    return EventAttendanceModel(
      id: json['id'] ?? 0,
      eventId: json['event_id'] ?? 0,
      uidThe: json['uid_the'] ?? '',
      tenHocSinh: json['ten_hoc_sinh'],
      thoiGianScan: json['thoi_gian_scan'] != null 
          ? DateTime.parse(json['thoi_gian_scan']) 
          : DateTime.now(),
      trangThai: json['trang_thai'] ?? 'Unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'uid_the': uidThe,
      'ten_hoc_sinh': tenHocSinh,
      'thoi_gian_scan': thoiGianScan.toIso8601String(),
      'trang_thai': trangThai,
    };
  }
}

// Make from Kiên and Dương with love
