import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/live_audio_service.dart';

class AiFloatingBubble extends StatefulWidget {
  const AiFloatingBubble({Key? key}) : super(key: key);

  @override
  State<AiFloatingBubble> createState() => _AiFloatingBubbleState();
}

class _AiFloatingBubbleState extends State<AiFloatingBubble> {
  bool _isTypingMode = false;
  double _amplitude = 0.0;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    liveAudioService.amplitudeStream.listen((amp) {
      if (mounted && !_isTypingMode) {
        setState(() {
          _amplitude = amp;
        });
      }
    });

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isTypingMode) {
        setState(() {
          _isTypingMode = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isTypingMode = !_isTypingMode;
      if (_isTypingMode) {
        _focusNode.requestFocus();
      } else {
        _focusNode.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Bubble dimensions
    final double targetWidth = _isTypingMode ? screenWidth - 32 : 260;
    final double targetHeight = _isTypingMode ? 48 : 60;
    
    // Waveform scale based on amplitude
    final double waveScale = 1.0 + (_amplitude * 0.5);

    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: _toggleMode,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: targetWidth,
          height: targetHeight,
          margin: EdgeInsets.only(
            // Đẩy lên khi có bàn phím
            bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(targetHeight / 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(targetHeight / 2),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: const Color(0xFF4F494A).withOpacity(0.7),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _isTypingMode
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Type to AI...',
                                hintStyle: TextStyle(color: Colors.white54),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (value) {
                                // Gửi text (Có thể thêm logic gọi Gemini API text)
                                _textController.clear();
                                _toggleMode();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.send, color: Colors.white.withOpacity(0.8), size: 20),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Biểu tượng AI / Waveform giả lập
                          Transform.scale(
                            scale: waveScale,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Color(0xFF469CEF), Color(0xFFD06CF4)],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
