import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ai_overlay_manager.dart';
import '../services/live_audio_service.dart';

class WakeWordService {
  final _vosk = VoskFlutterPlugin.instance();
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;
  
  bool _isListening = false;

  Future<void> init() async {
    try {
      debugPrint("DEBUG: Requesting microphone permission...");
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        debugPrint("DEBUG: Microphone permission denied. WakeWordService won't start.");
        return;
      }

      debugPrint("DEBUG: Loading Vosk Model from assets...");
      // Use the English model for Wake Word
      final modelPath = await ModelLoader().loadFromAssets('assets/models/vosk-model-en.zip');
      
      debugPrint("DEBUG: Creating Vosk Model...");
      _model = await _vosk.createModel(modelPath);
      
      debugPrint("DEBUG: Creating Recognizer...");
      _recognizer = await _vosk.createRecognizer(model: _model!, sampleRate: 16000);
      
      debugPrint("DEBUG: Init SpeechService...");
      _speechService = await _vosk.initSpeechService(_recognizer!);
      
      _speechService?.onPartial().listen((partialResult) {
        print("RAW VOSK PARTIAL: $partialResult");
        _processResult(partialResult);
      });
      
      _speechService?.onResult().listen((result) {
        print("RAW VOSK RESULT: $result");
        _processResult(result);
      });

      // Global listener: Always restart Wake Word when Live Session ends
      liveAudioService.stateStream.listen((state) {
        if (state == LiveSessionState.disconnected) {
          startListening();
        }
      });

      startListening();
      print("DEBUG: WakeWordService initialized and listening.");
    } catch (e) {
      print("WAKE_WORD_ERROR: $e");
    }
  }

  void _processResult(String resultText) {
    print("RAW VOSK: $resultText");
    final lowerText = resultText.toLowerCase();

    // Wake words - Using English model for "Hey AI"
    if (lowerText.contains("hey ai") || 
        lowerText.contains("hey a i") || 
        lowerText.contains("hay ai") ||
        lowerText.contains("hey i") ||
        lowerText.contains("a i")) { 
      
      print("DEBUG: Wake Word detected! Triggering Assistant...");
      _triggerAssistant();
    }
  }

  void _triggerAssistant() async {
    if (aiOverlayController.isActive) return;

    debugPrint("DEBUG: WAKE WORD DETECTED!");
    // Haptic feedback
    HapticFeedback.heavyImpact();

    // Hiện overlay (kích hoạt animation ngay lập tức)
    aiOverlayController.showOverlay();

    // DELAY 1000ms để animation sóng của Flutter chạy XONG HOÀN TOÀN.
    Future.delayed(const Duration(milliseconds: 1000), () async {
      // Kiểm tra race condition: Nếu user đã tắt overlay trước khi hết 1000ms
      if (!aiOverlayController.isActive) {
        return; 
      }

      // Dừng nhận diện wake word
      stopListening();

      // Bắt đầu live session
      await liveAudioService.startLiveSession();
    });
  }

  void startListening() async {
    if (!_isListening) {
      bool? started = await _speechService?.start(onRecognitionError: (e) {
        print("VOSK NATIVE ERROR: $e");
      });
      print("VOSK START_LISTENING RESULT: $started");
      _isListening = true;
    }
  }

  void stopListening() {
    if (_isListening) {
      _speechService?.stop();
      _isListening = false;
    }
  }
}

final wakeWordService = WakeWordService();
