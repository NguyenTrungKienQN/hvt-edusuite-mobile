import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'glowing_border.dart';
import 'widgets/ai_transcription_pill.dart';
import '../services/live_audio_service.dart';
import 'widgets/ai_orb/ai_orb.dart';
import 'widgets/ai_orb/orb_state.dart';
import 'floating_text_chat.dart'; // We will create this next

enum AiOverlayMode { hidden, voice, text, limbo }

class AiOverlayController extends ChangeNotifier {
  AiOverlayMode _mode = AiOverlayMode.hidden;
  AiOverlayMode get mode => _mode;

  bool get isActive => _mode != AiOverlayMode.hidden;

  void setMode(AiOverlayMode newMode) {
    _mode = newMode;
    notifyListeners();
  }

  // Backwards compatibility for wake word service
  void showOverlay() {
    setMode(AiOverlayMode.voice);
  }

  void hideOverlay() {
    setMode(AiOverlayMode.hidden);
  }
}

final aiOverlayController = AiOverlayController();

class AiOverlayManager extends StatefulWidget {
  final Widget child;

  const AiOverlayManager({Key? key, required this.child}) : super(key: key);

  @override
  State<AiOverlayManager> createState() => _AiOverlayManagerState();
}

class _AiOverlayManagerState extends State<AiOverlayManager>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _audioPlayer.setSource(AssetSource('Resources/AISound.wav'));

    aiOverlayController.addListener(_onModeChanged);
  }

  @override
  void dispose() {
    aiOverlayController.removeListener(_onModeChanged);
    _glowController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onModeChanged() {
    final mode = aiOverlayController.mode;
    if (mode == AiOverlayMode.voice) {
      if (!_glowController.isAnimating) {
        _glowController.forward(from: 0.0);
        _audioPlayer.stop().then((_) {
          _audioPlayer.play(AssetSource('Resources/AISound.wav'));
        });
      }
    } else {
      _glowController.reverse();
    }
    setState(() {});
  }

  void _handleBackgroundTap() {
    final mode = aiOverlayController.mode;
    if (mode == AiOverlayMode.text) {
      // Dismiss keyboard and switch to limbo
      FocusManager.instance.primaryFocus?.unfocus();
      aiOverlayController.setMode(AiOverlayMode.limbo);
    } else if (mode == AiOverlayMode.limbo) {
      // Completely dismiss
      aiOverlayController.hideOverlay();
    } else if (mode == AiOverlayMode.voice) {
      // Completely dismiss
      liveAudioService.stopLiveSession();
      aiOverlayController.hideOverlay();
    }
  }

  void _handleOrbSingleTap() {
    final mode = aiOverlayController.mode;
    if (mode == AiOverlayMode.limbo) {
      aiOverlayController.setMode(AiOverlayMode.voice);
      liveAudioService.startLiveSession();
    }
  }

  void _handleOrbDoubleTap() {
    final mode = aiOverlayController.mode;
    if (mode == AiOverlayMode.voice || mode == AiOverlayMode.limbo) {
      liveAudioService.stopLiveSession();
      aiOverlayController.setMode(AiOverlayMode.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = aiOverlayController.mode;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          // 1. Giao diện gốc
          widget.child,

          // 2. Lớp chặn tap background
          Positioned.fill(
            child: mode != AiOverlayMode.hidden
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _handleBackgroundTap,
                    child: Container(color: Colors.transparent),
                  )
                : const SizedBox.shrink(),
          ),

          // 3. Glowing Border (Chỉ hiện ở Voice mode)
          IgnorePointer(
            child: mode == AiOverlayMode.voice || _glowController.isAnimating
                ? GlowingBorder(animation: _glowController)
                : const SizedBox.shrink(),
          ),

          // 4. Khung chat nổi và Orb morphing (Bắt buộc phải có Overlay để TextField nhận phím)
          Positioned.fill(
            key: const ValueKey('ai_overlay_layer'),
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (context) => ListenableBuilder(
                    listenable: aiOverlayController,
                    builder: (context, child) => FloatingTextChat(
                      mode: aiOverlayController.mode,
                      onOrbSingleTap: _handleOrbSingleTap,
                      onOrbDoubleTap: _handleOrbDoubleTap,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 5. Transcription Pill (Chỉ hiện ở Voice mode)
          IgnorePointer(
            child: mode == AiOverlayMode.voice
                ? const AiTranscriptionPill()
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
