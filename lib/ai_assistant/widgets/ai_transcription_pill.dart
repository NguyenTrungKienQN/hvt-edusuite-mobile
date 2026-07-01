import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../services/live_audio_service.dart';

class AiTranscriptionPill extends StatefulWidget {
  const AiTranscriptionPill({super.key});

  @override
  State<AiTranscriptionPill> createState() => _AiTranscriptionPillState();
}

class _AiTranscriptionPillState extends State<AiTranscriptionPill> {
  String _currentText = "";
  LiveSessionState _currentState = LiveSessionState.disconnected;
  bool _isProcessing = false;
  Timer? _silenceTimer;

  StreamSubscription? _stateSub;
  StreamSubscription? _transcriptSub;
  StreamSubscription? _ampSub;

  @override
  void initState() {
    super.initState();
    _currentState = liveAudioService.currentState;

    _stateSub = liveAudioService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          // Clear text when transitioning back to listening from aiSpeaking
          if (_currentState == LiveSessionState.aiSpeaking &&
              state == LiveSessionState.listening) {
            // Delay clearing slightly so it doesn't vanish instantly before they finish reading
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted &&
                  liveAudioService.currentState == LiveSessionState.listening) {
                setState(() {
                  _currentText = "";
                  _isProcessing = false; // Hide pill again until they speak
                });
              }
            });
          }

          if (state == LiveSessionState.disconnected) {
            _currentText = "";
            _isProcessing = false;
            _silenceTimer?.cancel();
          }

          _currentState = state;
        });
      }
    });

    _transcriptSub = liveAudioService.transcriptStream.listen((text) {
      if (mounted) {
        setState(() {
          _isProcessing = false; // Got text, no longer just processing
          if (_currentText.length > 200) {
            _currentText = text; // reset if getting too long to avoid huge pill
          } else {
            _currentText = _currentText.isEmpty ? text : "$_currentText $text";
          }
        });
      }
    });

    _ampSub = liveAudioService.amplitudeStream.listen((amp) {
      // Detect when user is speaking
      if (_currentState == LiveSessionState.listening && _currentText.isEmpty) {
        if (amp > 0.03) {
          // User is making noise. Hide the "Working" pill if it's showing.
          if (_isProcessing && mounted) {
            setState(() => _isProcessing = false);
          }
          _resetSilenceTimer();
        }
      }
    });
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted &&
          _currentState == LiveSessionState.listening &&
          _currentText.isEmpty) {
        // User has been silent for 1.5s after speaking. Assume they are done and AI is processing.
        setState(() {
          _isProcessing = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _stateSub?.cancel();
    _transcriptSub?.cancel();
    _ampSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentState == LiveSessionState.disconnected ||
        _currentState == LiveSessionState.connecting) {
      return const SizedBox.shrink();
    }

    final isSpeaking = _currentState == LiveSessionState.aiSpeaking;
    final isWorking = _currentText.isEmpty && !isSpeaking;
    final shouldShow = _isProcessing || _currentText.isNotEmpty || isSpeaking;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 24.0),
          child: Align(
            alignment: Alignment.topCenter,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: shouldShow ? 1.0 : 0.0,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                child: !shouldShow
                    ? const SizedBox(width: 140, height: 0)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.85,
                              minWidth: isWorking ? 140 : 0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                )
                              ],
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: isWorking ? 20 : 28,
                              vertical: isWorking ? 12 : 20,
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: isSpeaking
                                  ? const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      key: ValueKey('speaking'),
                                      children: [
                                        Icon(CupertinoIcons.speaker_2_fill,
                                            color: Colors.white, size: 16),
                                        SizedBox(width: 8),
                                        Text(
                                          "AI đang nói...",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w400,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    )
                                  : isWorking
                                      ? const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          key: ValueKey('working'),
                                          children: [
                                            CupertinoActivityIndicator(
                                              color: Colors.white,
                                              radius: 11,
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              "Đang xử lý...",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize:
                                                    15, // Slightly smaller font
                                                fontWeight: FontWeight
                                                    .w400, // Lighter weight to match typical OS text
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          _currentText.trim(),
                                          key: const ValueKey('text'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 17, // Adjusted font size
                                            fontWeight: FontWeight
                                                .w400, // Adjusted weight
                                            height: 1.4,
                                            letterSpacing: 0.3,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
