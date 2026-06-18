import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

class AiChatScreen extends StatefulWidget {
  final String role; // 'parent' or 'teacher'

  const AiChatScreen({super.key, required this.role});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Welcome message
    _messages.add({
      'role': 'model',
      'text': widget.role == 'parent'
          ? 'Xin chào phụ huynh! Tôi là Trợ lý AI Học đường. Tôi có thể hỗ trợ giải đáp thông tin học tập, phân tích tình hình điểm danh của con, hoặc trả lời các thắc mắc chung về nhà trường. Bạn cần hỗ trợ gì hôm nay?'
          : 'Xin chào Thầy/Cô! Tôi là Trợ lý AI Học đường. Tôi có thể hỗ trợ phân tích hành vi, thống kê điểm danh nhanh cho học sinh trong lớp chủ nhiệm của Thầy/Cô. Thầy/Cô cần hỗ trợ thông tin gì ạ?',
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isTyping = true;
    });
    _scrollToBottom();

    // Prepare history to send to Gemini API
    // Gemini API structure for history is custom or matches the backend format.
    // Our backend expects list of objects with role ('user' or 'model') and text.
    final history = _messages.sublist(1, _messages.length - 1).map((m) {
      return {
        'role': m['role']!,
        'text': m['text']!,
      };
    }).toList();

    try {
      final res = await apiService.sendChatMessage(text, history);
      if (res.data != null && res.data['reply'] != null) {
        setState(() {
          _messages.add({'role': 'model', 'text': res.data['reply']});
        });
      } else {
        setState(() {
          _messages.add({
            'role': 'model',
            'text': 'Xin lỗi, tôi gặp lỗi khi xử lý câu hỏi này. Thầy cô/phụ huynh vui lòng thử lại sau.'
          });
        });
      }
    } on DioException catch (e) {
      String errMsg = 'Lỗi kết nối máy chủ AI.';
      if (e.response != null && e.response!.data != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('detail')) {
          errMsg = data['detail'].toString();
        }
      }
      setState(() {
        _messages.add({'role': 'model', 'text': '⚠️ $errMsg'});
      });
    } catch (_) {
      setState(() {
        _messages.add({'role': 'model', 'text': '⚠️ Đã xảy ra lỗi không xác định.'});
      });
    } finally {
      setState(() {
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2D3142)),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFF6C63FF),
              child: Icon(Icons.psychology_rounded, color: Colors.white),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trợ lý AI Học đường',
                  style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Trực tuyến • Gemini AI',
                  style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600),
                )
              ],
            )
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF6C63FF) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(
                        color: isUser ? Colors.white : const Color(0xFF2D3142),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI đang suy nghĩ...',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 12,
              top: 12,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FC),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Nhập câu hỏi tại đây...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  mini: true,
                  backgroundColor: const Color(0xFF6C63FF),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
