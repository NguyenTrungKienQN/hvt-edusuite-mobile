import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/event_model.dart';
import '../services/api_service.dart';

class EventFormScreen extends StatefulWidget {
  final EventModel? event;

  const EventFormScreen({super.key, this.event});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _tenController;
  late TextEditingController _lopController;
  late TextEditingController _muonController;
  
  DateTime? _batDau;
  DateTime? _ketThuc;
  bool _isLoading = false;

  final DateFormat _dateFormat = DateFormat('HH:mm dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _tenController = TextEditingController(text: widget.event?.ten ?? '');
    _lopController = TextEditingController(text: widget.event?.lop ?? '');
    _muonController = TextEditingController(text: widget.event?.muonSauPhut.toString() ?? '0');
    
    _batDau = widget.event?.batDau ?? DateTime.now();
    _ketThuc = widget.event?.ketThuc ?? DateTime.now().add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _tenController.dispose();
    _lopController.dispose();
    _muonController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    final DateTime initialDate = (isStart ? _batDau : _ketThuc) ?? DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6C63FF),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1F2232),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      if (!context.mounted) return;
      final TimeOfDay initialTime = TimeOfDay.fromDateTime(initialDate);
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: initialTime,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF6C63FF),
                onPrimary: Colors.white,
                onSurface: Color(0xFF1F2232),
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          final result = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isStart) {
            _batDau = result;
            if (_ketThuc != null && _ketThuc!.isBefore(_batDau!)) {
              _ketThuc = _batDau!.add(const Duration(hours: 1));
            }
          } else {
            _ketThuc = result;
          }
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_batDau == null || _ketThuc == null) {
      Fluttertoast.showToast(msg: "Vui lòng chọn thời gian");
      return;
    }

    if (_ketThuc!.isBefore(_batDau!)) {
      Fluttertoast.showToast(msg: "Thời gian kết thúc phải sau bắt đầu");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'ten': _tenController.text.trim(),
        'lop': _lopController.text.trim(),
        'bat_dau': _batDau!.toIso8601String(),
        'ket_thuc': _ketThuc!.toIso8601String(),
        'muon_sau_phut': int.tryParse(_muonController.text.trim()) ?? 0,
      };

      if (widget.event == null) {
        final res = await apiService.createEvent(data);
        if (res.statusCode == 200 || res.statusCode == 201) {
          Fluttertoast.showToast(msg: "Đã tạo sự kiện");
          if (mounted) Navigator.pop(context, true);
        } else {
          Fluttertoast.showToast(msg: "Lỗi tạo sự kiện", backgroundColor: Colors.red);
        }
      } else {
        final res = await apiService.updateEvent(widget.event!.id, data);
        if (res.statusCode == 200) {
          Fluttertoast.showToast(msg: "Đã cập nhật sự kiện");
          if (mounted) Navigator.pop(context, true);
        } else {
          Fluttertoast.showToast(msg: "Lỗi cập nhật sự kiện", backgroundColor: Colors.red);
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi kết nối", backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: Text(
          isEditing ? 'Sửa sự kiện' : 'Tạo sự kiện',
          style: const TextStyle(color: Color(0xFF1F2232), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F2232)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Tên sự kiện *'),
              _buildTextField(
                controller: _tenController,
                hintText: 'Nhập tên sự kiện',
                icon: Icons.event_note_rounded,
                validator: (v) => v!.trim().isEmpty ? 'Bắt buộc' : null,
              ),
              const SizedBox(height: 24),

              _buildLabel('Lớp (Tùy chọn)'),
              _buildTextField(
                controller: _lopController,
                hintText: 'Ví dụ: 10A1',
                icon: Icons.groups_rounded,
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Bắt đầu *'),
                        _buildDateTimePicker(
                          date: _batDau,
                          onTap: () => _selectDateTime(context, true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Kết thúc *'),
                        _buildDateTimePicker(
                          date: _ketThuc,
                          onTap: () => _selectDateTime(context, false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildLabel('Tính muộn sau (phút)'),
              _buildTextField(
                controller: _muonController,
                hintText: '0',
                icon: Icons.timer_rounded,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v!.trim().isNotEmpty && int.tryParse(v.trim()) == null) {
                    return 'Phải là số';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 48),

              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        isEditing ? 'Lưu thay đổi' : 'Tạo sự kiện',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1F2232),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, color: const Color(0xFF6C63FF)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDateTimePicker({required DateTime? date, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded, color: Color(0xFF6C63FF), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null ? _dateFormat.format(date) : 'Chọn',
                style: const TextStyle(fontSize: 14, color: Color(0xFF1F2232)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Make from Kiên and Dương with love
