import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'glowing_border.dart';
import 'widgets/ai_transcription_pill.dart';
import '../services/live_audio_service.dart';

class AiOverlayController extends ChangeNotifier {
  bool _isActive = false;
  bool get isActive => _isActive;
  void Function()? _showOverlayCallback;
  void Function()? _hideOverlayCallback;

  void showOverlay() {
    _showOverlayCallback?.call();
    if (!_isActive) {
      _isActive = true;
      notifyListeners();
    }
  }

  void hideOverlay() {
    _hideOverlayCallback?.call();
    if (_isActive) {
      _isActive = false;
      notifyListeners();
    }
  }
}

final aiOverlayController = AiOverlayController();

class AiOverlayManager extends StatefulWidget {
  final Widget child;

  const AiOverlayManager({Key? key, required this.child}) : super(key: key);

  @override
  State<AiOverlayManager> createState() => _AiOverlayManagerState();
}

class _AiOverlayManagerState extends State<AiOverlayManager> with TickerProviderStateMixin {
  late AnimationController _glowController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _overlayActive = false;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Pre-load audio to eliminate disk I/O lag when triggering
    _audioPlayer.setSource(AssetSource('Resources/AISound.wav'));

    aiOverlayController._showOverlayCallback = _showOverlay;
    aiOverlayController._hideOverlayCallback = _hideOverlay;
  }

  void _showOverlay() {
    if (!_overlayActive) {
      setState(() {
        _overlayActive = true;
      });
      // Start the visual animation immediately
      _glowController.forward(from: 0.0);
      
      // Stop resets the player state. Play will replay from the beginning.
      // Since it was played/loaded once, it is cached and instant.
      _audioPlayer.stop().then((_) {
        _audioPlayer.play(AssetSource('Resources/AISound.wav'));
      });
    }
  }

  void _hideOverlay() {
    if (_overlayActive) {
      _glowController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _overlayActive = false;
          });
        }
      });
    }
  }

  void _dismissOverlay() {
    aiOverlayController.hideOverlay();
    liveAudioService.stopLiveSession();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          // Giao diện ứng dụng gốc — luôn hiển thị đầy đủ
          widget.child,
          
          // Lớp chặn tap để đóng overlay (vô hình, trong suốt)
          if (_overlayActive)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _dismissOverlay,
                child: Container(color: Colors.transparent),
              ),
            ),
            
          // Viền sáng Apple Intelligence — lan tỏa từ cạnh phải
          if (_overlayActive)
            IgnorePointer(
              child: GlowingBorder(
                animation: _glowController,
              ),
            ),

          // The AI-style live transcription and processing pill
          if (_overlayActive)
            const IgnorePointer(
              child: AiTranscriptionPill(),
            ),
        ],
      ),
    );
  }
}
