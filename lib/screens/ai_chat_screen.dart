import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'ai_live_screen.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  final String role; // 'parent' or 'teacher'

  const AiChatScreen({super.key, required this.role});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasSeenWelcome = false;

  // Chat conversation state
  final List<Map<String, String>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  
  late AnimationController _bobbingController;
  late Animation<double> _bobbingAnimation;
  late AnimationController _dotsAnimationController;

  // Speech to Text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  
  // Text to Speech
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;
  String? _currentlyPlayingText;

  @override
  void initState() {
    super.initState();
    _checkWelcomePreference();
    _initTTS();

    _bobbingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _bobbingAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _bobbingController, curve: Curves.easeInOut),
    );

    _dotsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _bobbingController.dispose();
    _dotsAnimationController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkWelcomePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_welcome') ?? false;
    if (mounted) {
      setState(() {
        _hasSeenWelcome = hasSeen;
        _isLoading = false;
      });
    }
  }

  Future<void> _setWelcomePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome', true);
    if (mounted) {
      setState(() {
        _hasSeenWelcome = true;
      });
    }
  }

  void _initTTS() {
    _flutterTts.setLanguage("vi-VN");
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentlyPlayingText = null;
        });
      }
    });
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (mounted && (val == 'done' || val == 'notListening')) {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (available) {
        if (mounted) setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            if (mounted) {
              setState(() {
                _controller.text = val.recognizedWords;
              });
            }
          },
          listenOptions: stt.SpeechListenOptions(localeId: "vi_VN"),
        );
      }
    } else {
      if (mounted) setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _speak(String text) async {
    if (_isPlaying && _currentlyPlayingText == text) {
      await _flutterTts.stop();
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentlyPlayingText = null;
        });
      }
    } else {
      await _flutterTts.stop();
      if (mounted) {
        setState(() {
          _isPlaying = true;
          _currentlyPlayingText = text;
        });
      }
      await _flutterTts.speak(text);
    }
  }

  void _regenerateLast() {
    if (_messages.isEmpty) return;
    
    String? lastUserMessage;
    int lastModelIndex = -1;
    
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i]['role'] == 'model' && lastModelIndex == -1) {
        lastModelIndex = i;
      }
      if (_messages[i]['role'] == 'user') {
        lastUserMessage = _messages[i]['text'];
        break;
      }
    }

    if (lastUserMessage != null) {
      if (lastModelIndex != -1) {
        setState(() {
          _messages.removeAt(lastModelIndex);
        });
      }
      setState(() {
        _isTyping = true;
      });
      _scrollToBottom();
      _fetchAiReply(lastUserMessage);
    }
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

    await _fetchAiReply(text);
  }

  Future<void> _startChatWithTemplate(String prompt) async {
    setState(() {
      _messages.add({'role': 'user', 'text': prompt});
      _isTyping = true;
    });
    _scrollToBottom();

    await _fetchAiReply(prompt);
  }

  Future<void> _fetchAiReply(String text) async {
    // Prepare history to send to Gemini API
    final history = _messages.sublist(0, _messages.length - 1).map((m) {
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
            'text': 'Linh Thú AI gặp lỗi khi xử lý câu hỏi này. Vui lòng thử lại sau.'
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

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Đã sao chép vào bộ nhớ tạm!',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: Color(0xFF6C63FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        duration: Duration(seconds: 2),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
      );
    }

    if (!_hasSeenWelcome) {
      return Scaffold(
        body: _buildWelcomeView(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _buildDashboardOrChatView(),
      ),
    );
  }

  Widget _buildWelcomeView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8EBFC), Color(0xFFF4F7FC)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 10),
              // Bobbing Mascot - Transparent Background, No Borders
              AnimatedBuilder(
                animation: _bobbingAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _bobbingAnimation.value),
                    child: Image.asset(
                      'assets/linhthu.png',
                      width: MediaQuery.of(context).size.width * 0.6,
                      fit: BoxFit.contain,
                    ),
                  );
                },
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Hỏi bất cứ điều gì\nTrợ lý Linh Thú AI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF2D3142),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.role == 'parent'
                        ? 'Linh thú luôn ở đây để giúp giải đáp thông tin trường lớp và tình hình học tập nhanh nhất.'
                        : 'Linh thú hỗ trợ soạn bài giảng, soạn thông báo gửi phụ huynh và phân tích tình hình lớp học.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  GestureDetector(
                    onTap: _setWelcomePreference,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF8B83FF)],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Bắt đầu →',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardOrChatView() {
    final authState = ref.watch(authProvider);
    final isParent = widget.role == 'parent';

    // Retrieve name for custom display
    String displayName = '';
    if (isParent) {
      displayName = authState.student?.tenPhuHuynh ?? 'Phụ huynh';
    } else {
      displayName = authState.user?.accountname ?? 'Thầy/Cô';
    }

    final studentName = authState.student?.ten ?? 'con';
    final studentClass = authState.student?.lop ?? 'học đường';
    final teacherClass = authState.user?.lopQuyen ?? 'chủ nhiệm';

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          Positioned.fill(
            child: _messages.isEmpty
                ? _buildLandingContent(displayName, isParent, studentName, studentClass, teacherClass)
                : _buildConversationContent(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildInputBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildLandingContent(
    String displayName,
    bool isParent,
    String studentName,
    String studentClass,
    String teacherClass,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Center Mascot Logo — Free floating, no borders
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Image.asset(
                'assets/linhthu.png',
                width: 72,
                height: 72,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Greetings
          Text(
            'Xin chào, $displayName 👋',
            style: const TextStyle(
              color: Color(0xFF2D3142),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Linh Thú AI có thể giúp gì?',
            style: TextStyle(color: Colors.grey[600], fontSize: 15),
          ),
          const SizedBox(height: 24),

          // 2-Column Grid Layout
          SizedBox(
            height: 210,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tall Left Card
                Expanded(
                  child: GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 28),
                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isParent ? 'Hỏi đáp\nhọc đường' : 'Trợ giảng\nsư phạm',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Hỏi Linh Thú AI',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Text(
                              'Bắt đầu →',
                              style: TextStyle(
                                color: Color(0xFF6C63FF),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Right Column
                Expanded(
                  child: Column(
                    children: [
                      // Right Top Card
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (isParent) {
                              _startChatWithTemplate(
                                'Hãy soạn giúp tôi một lá đơn xin nghỉ học chuyên nghiệp gửi giáo viên chủ nhiệm cho con học lớp $studentClass được nghỉ học 1 ngày hôm nay vì lý do bị sốt phát ban.'
                              );
                            } else {
                              _startChatWithTemplate(
                                'Hãy thiết kế một đề cương giáo án chi tiết 45 phút cho tiết học về chủ đề Bảo vệ Môi trường dành cho học sinh lớp $teacherClass.'
                              );
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0EEFF),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isParent ? Icons.assignment_outlined : Icons.menu_book_outlined,
                                    color: const Color(0xFF6C63FF),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        isParent ? 'Xin nghỉ phép' : 'Soạn giáo án',
                                        style: const TextStyle(
                                          color: Color(0xFF2D3142),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isParent ? 'Tự động soạn đơn' : 'Thiết kế bài giảng nhanh',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Right Bottom Card
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (isParent) {
                              _startChatWithTemplate(
                                'Hãy tóm tắt giúp tôi các ý chính và các mốc thời gian quan trọng cần lưu ý trong bản thông báo họp phụ huynh/đóng học phí của nhà trường.'
                              );
                            } else {
                              _startChatWithTemplate(
                                'Hãy soạn giúp tôi một tin nhắn gửi phụ huynh lớp $teacherClass để thông báo về buổi họp phụ huynh cuối kỳ diễn ra vào sáng thứ Bảy tuần này.'
                              );
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE8FF),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isParent ? Icons.summarize_outlined : Icons.sms_outlined,
                                    color: const Color(0xFF8B5CF6),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        isParent ? 'Tóm tắt' : 'Soạn tin nhắn',
                                        style: const TextStyle(
                                          color: Color(0xFF2D3142),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isParent ? 'Rút gọn thông báo' : 'Thông báo gửi phụ huynh',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                                              ),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Recently Added Tiles
                  const Text(
                    'Thêm gần đây',
                    style: TextStyle(
                      color: Color(0xFF2D3142),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (isParent) ...[
                    _buildTemplateTile(
                      icon: Icons.psychology_rounded,
                      iconBgColor: const Color(0xFFF0EEFF),
                      iconColor: const Color(0xFF6C63FF),
                      title: 'Phân tích hành vi',
                      subtitle: 'Nhận xét hành vi của con',
                      prompt: 'Hãy phân tích và đưa ra nhận xét hành vi của em $studentName học lớp $studentClass dựa trên các ghi nhận ở trường và gợi ý giúp tôi một số phương pháp điều chỉnh hành vi phù hợp.',
                    ),
                    _buildTemplateTile(
                      icon: Icons.lightbulb_outline_rounded,
                      iconBgColor: const Color(0xFFE6F4F1),
                      iconColor: const Color(0xFF0D9488),
                      title: 'Góc giáo dục con',
                      subtitle: 'Lời khuyên nuôi dạy trẻ từ AI',
                      prompt: 'Hãy gợi ý cho tôi một số phương pháp hiệu quả tại nhà để giúp trẻ lớp $studentClass tập trung tự giác làm bài tập mà không cần ba mẹ nhắc nhở nhiều.',
                    ),
                    _buildTemplateTile(
                      icon: Icons.verified_user_outlined,
                      iconBgColor: const Color(0xFFFFF7ED),
                      iconColor: const Color(0xFFEA580C),
                      title: 'An toàn học đường',
                      subtitle: 'Kỹ năng phòng vệ cho học sinh',
                      prompt: 'Hãy hướng dẫn các quy tắc an toàn học đường quan trọng và kỹ năng xử lý tình huống khi bị bắt nạt mà học sinh cần biết.',
                    ),
                  ] else ...[
                    _buildTemplateTile(
                      icon: Icons.rate_review_rounded,
                      iconBgColor: const Color(0xFFF0EEFF),
                      iconColor: const Color(0xFF6C63FF),
                      title: 'Nhận xét học bạ',
                      subtitle: 'Gợi ý lời phê học bạ thông minh',
                      prompt: 'Hãy gợi ý giúp tôi 5 mẫu nhận xét học bạ cuối kỳ tích cực, chân thành dành cho những học sinh chăm chỉ học tập nhưng chưa đạt điểm số xuất sắc.',
                    ),
                    _buildTemplateTile(
                      icon: Icons.event_available_rounded,
                      iconBgColor: const Color(0xFFE6F4F1),
                      iconColor: const Color(0xFF0D9488),
                      title: 'Ý tưởng sự kiện',
                      subtitle: 'Lên kế hoạch hoạt động sinh hoạt lớp',
                      prompt: 'Hãy gợi ý 3 trò chơi sinh hoạt lớp vui nhộn, gắn kết tinh thần đoàn kết phù hợp cho học sinh lớp $teacherClass.',
                    ),
                    _buildTemplateTile(
                      icon: Icons.fact_check_outlined,
                      iconBgColor: const Color(0xFFFFF7ED),
                      iconColor: const Color(0xFFEA580C),
                      title: 'Thống kê chuyên cần',
                      subtitle: 'Cải thiện tỷ lệ chuyên cần của lớp',
                      prompt: 'Chia sẻ các biện pháp sư phạm hiệu quả giúp giáo viên chủ nhiệm giảm thiểu tình trạng học sinh lớp $teacherClass đi học trễ hoặc vắng không phép.',
                    ),
                  ],
                ],
              ),
            );
  }

  Widget _buildConversationContent() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 120,
      ),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isTyping && index == _messages.length) {
          return _buildTypingIndicator();
        }
        final msg = _messages[index];
        final isUser = msg['role'] == 'user';
        
        if (isUser) {
          return _buildUserBubble(msg['text'] ?? '');
        } else {
          return _buildAiBubble(msg['text'] ?? '', index);
        }
      },
    );
  }

  Widget _buildUserBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, left: 50),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F9),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF1F1F1F),
            fontSize: 17,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildAiBubble(String text, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Free Mascot Image — no round border/avatar circle
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(top: 4),
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/linhthu.png'),
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: MarkdownBody(
                    data: text,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        color: Color(0xFF1F1F1F),
                        fontSize: 16,
                        height: 1.5,
                      ),
                      listBullet: const TextStyle(
                        color: Color(0xFF1F1F1F),
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildBubbleActionIcon(Icons.refresh_rounded, _regenerateLast),
                        const SizedBox(width: 16),
                        _buildBubbleActionIcon(Icons.copy_rounded, () => _copyToClipboard(text)),
                      ],
                    ),
                    _buildBubbleActionIcon(
                      _isPlaying && _currentlyPlayingText == text ? Icons.stop_circle_outlined : Icons.volume_up_outlined, 
                      () => _speak(text),
                      color: _isPlaying && _currentlyPlayingText == text ? Colors.red : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Linh Thú là AI và có thể mắc sai sót.',
                  style: TextStyle(
                    color: Colors.grey[450] ?? Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleActionIcon(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        size: 18,
        color: color ?? Colors.grey[600],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Free Mascot Image — no border circle
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/linhthu.png'),
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _dotsAnimationController,
                  builder: (context, child) {
                    return Row(
                      children: List.generate(3, (index) {
                        final double delay = index * 0.2;
                        final double value = ((_dotsAnimationController.value + delay) % 1.0);
                        final double size = 6 + (4 * (1.0 - (value - 0.5).abs() * 2));
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          alignment: Alignment.center,
                          child: Container(
                            width: size,
                            height: size,
                            decoration: const BoxDecoration(
                              color: Color(0xFF6C63FF),
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  'Linh Thú đang suy nghĩ...',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final hasText = _controller.text.trim().isNotEmpty;
    
    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F9),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFFE1E5F2), width: 0.5),
      ),
      child: Row(
        children: [
          PopupMenuButton<String>(
            icon: Icon(Icons.add_rounded, color: Colors.grey[700], size: 28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            offset: const Offset(0, -60),
            onSelected: (value) {
              if (value == 'new_chat') {
                setState(() {
                  _messages.clear();
                });
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'new_chat',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, color: Color(0xFF10B981)),
                    SizedBox(width: 12),
                    Text('Trò chuyện mới', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: _controller,
                style: const TextStyle(fontSize: 17, color: Color(0xFF1F1F1F)),
                decoration: InputDecoration(
                  hintText: _isListening ? 'Đang nghe...' : 'Hỏi Linh Thú...',
                  hintStyle: TextStyle(color: _isListening ? const Color(0xFF6C63FF) : Colors.grey, fontSize: 17),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          if (!hasText)
            IconButton(
              icon: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded, 
                color: _isListening ? const Color(0xFF6C63FF) : Colors.grey[700], 
                size: 26
              ),
              onPressed: _listen,
            ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              if (hasText) {
                _sendMessage();
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AiLiveScreen()),
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: hasText ? const Color(0xFF1A73E8) : const Color(0xFFEDE8FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasText ? Icons.send_rounded : Icons.auto_awesome_rounded,
                color: hasText ? Colors.white : const Color(0xFF8B5CF6),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildTemplateTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String prompt,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF2D3142),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          onTap: () => _startChatWithTemplate(prompt),
        ),
      ),
    );
  }
}

// Make from Kiên and Dương with love
