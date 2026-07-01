import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/api_service.dart';

import '../services/live_audio_service.dart';
import 'ai_overlay_manager.dart'; // To get AiOverlayMode
import 'widgets/ai_orb/ai_orb.dart';
import 'widgets/ai_orb/orb_state.dart';

class FloatingTextChat extends StatefulWidget {
  final AiOverlayMode mode;
  final VoidCallback onOrbSingleTap;
  final VoidCallback onOrbDoubleTap;

  const FloatingTextChat({
    super.key,
    required this.mode,
    required this.onOrbSingleTap,
    required this.onOrbDoubleTap,
  });

  @override
  State<FloatingTextChat> createState() => _FloatingTextChatState();
}

class _FloatingTextChatState extends State<FloatingTextChat> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _aiOutput = "Xin chào! HVT EduSuite AI có thể giúp gì cho bạn hôm nay?";
  bool _isTyping = false;
  bool _wasTextMode = false;

  // History for backend context
  final List<Map<String, String>> _history = [];

  @override
  void initState() {
    super.initState();
    // Only auto-focus if we start in text mode
    if (widget.mode == AiOverlayMode.text) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(FloatingTextChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != AiOverlayMode.text && widget.mode == AiOverlayMode.text) {
      _focusNode.requestFocus();
    } else if (oldWidget.mode == AiOverlayMode.text && widget.mode != AiOverlayMode.text) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _isTyping = true;
      _aiOutput = ""; // Clear current output or show loading visually
    });

    try {
      final res = await apiService.sendChatMessage(text, _history);
      if (res.data != null && res.data['reply'] != null) {
        final reply = res.data['reply'];
        setState(() {
          _aiOutput = reply;
          _history.add({'role': 'user', 'text': text});
          _history.add({'role': 'model', 'text': reply});
        });
      } else {
        setState(() {
          _aiOutput = 'HVT EduSuite AI gặp lỗi khi xử lý. Vui lòng thử lại sau.';
        });
      }
    } catch (e) {
      setState(() {
        _aiOutput = 'Không thể kết nối. Vui lòng kiểm tra mạng.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTextMode = widget.mode == AiOverlayMode.text;
    final bool isHidden = widget.mode == AiOverlayMode.hidden;
    
    // Remember if we were in text mode to keep showing output while transitioning
    if (isTextMode) _wasTextMode = true;
    if (isHidden) _wasTextMode = false;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Nửa trên: Hiển thị Output của AI (Fade in/out)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            top: isTextMode ? 80 : 40,
            left: 16,
            right: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isTextMode ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !isTextMode,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'EduSuite AI',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_isTyping)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.purple),
                              ),
                            )
                          else
                            Flexible(
                              child: SingleChildScrollView(
                                child: MarkdownBody(
                                  data: _aiOutput,
                                  styleSheet: MarkdownStyleSheet(
                                    p: const TextStyle(color: Colors.black87, fontSize: 16, height: 1.5),
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
          ),
          
          // Nửa dưới: Bàn phím / Text Input morphing với AiOrb
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                bottom: isTextMode ? MediaQuery.of(context).viewInsets.bottom + 32 : 32,
              ),
              child: AnimatedScale(
                scale: isHidden ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                curve: isHidden ? Curves.easeInBack : Curves.easeOutBack, // Hiệu ứng thu vào/nở ra kiểu Siri
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  width: isTextMode ? MediaQuery.of(context).size.width - 32 : 80,
                  height: isTextMode ? 56 : 80,
                  decoration: BoxDecoration(
                    color: isTextMode ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(isTextMode ? 28 : 40),
                    boxShadow: isTextMode ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      )
                    ] : null,
                  ),
                  child: AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState: isTextMode ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    firstChild: SizedBox(
                      width: 80,
                      height: 80,
                      child: GestureDetector(
                        onTap: widget.onOrbSingleTap,
                        onDoubleTap: widget.onOrbDoubleTap,
                        child: StreamBuilder<LiveSessionState>(
                          stream: liveAudioService.stateStream,
                          initialData: liveAudioService.currentState,
                          builder: (context, snapshot) {
                            if (widget.mode == AiOverlayMode.limbo) {
                              return const AiOrb(size: 80, state: OrbState.idle);
                            }
                            
                            final liveState = snapshot.data ?? LiveSessionState.disconnected;
                            OrbState orbState;
                            switch (liveState) {
                              case LiveSessionState.listening:
                                orbState = OrbState.listening;
                                break;
                              case LiveSessionState.aiSpeaking:
                                orbState = OrbState.speaking;
                                break;
                              case LiveSessionState.connecting:
                                orbState = OrbState.thinking;
                                break;
                              case LiveSessionState.disconnected:
                              case LiveSessionState.paused:
                              default:
                                orbState = OrbState.idle;
                            }
                            return AiOrb(size: 80, state: orbState);
                          },
                        ),
                      ),
                    ),
                    secondChild: SizedBox(
                      width: MediaQuery.of(context).size.width - 32,
                      height: 56,
                      child: Row(
                        children: [
                          const SizedBox(width: 20),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                              style: const TextStyle(color: Colors.black87, fontSize: 16),
                              decoration: const InputDecoration(
                                hintText: 'Nhập tin nhắn cho AI...',
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: Colors.black38),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send, color: Colors.purple),
                            onPressed: _sendMessage,
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
