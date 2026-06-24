import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:record/record.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'api_service.dart';
import 'auth_service.dart';

enum LiveSessionState { disconnected, connecting, listening, aiSpeaking, paused }

class LiveAudioService {
  WebSocketChannel? _channel;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final FlutterTts _flutterTts = FlutterTts();
  
  StreamSubscription? _recordSub;
  StreamSubscription? _wsSub;

  final _stateController = StreamController<LiveSessionState>.broadcast();
  Stream<LiveSessionState> get stateStream => _stateController.stream;

  final _amplitudeController = StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  LiveSessionState _currentState = LiveSessionState.disconnected;
  LiveSessionState get currentState => _currentState;

  bool _isMuted = false;
  bool get isMuted => _isMuted;
  
  bool _isLive = false;
  bool get isLive => _isLive;

  LiveAudioService() {
    _flutterTts.setStartHandler(() {
      _setState(LiveSessionState.aiSpeaking);
    });
    _flutterTts.setCompletionHandler(() {
      if (_isLive && !_isMuted) {
        _setState(LiveSessionState.listening);
      } else if (_isLive && _isMuted) {
        _setState(LiveSessionState.paused);
      }
    });
  }

  void _setState(LiveSessionState state) {
    if (_currentState != state) {
      _currentState = state;
      _stateController.add(state);
    }
  }

  // Configuration
  static const int _sampleRateInput = 16000;
  String get _wsUrl {
    final baseUrl = apiService.baseUrl;
    if (baseUrl.startsWith('https://')) {
      return '${baseUrl.replaceFirst('https://', 'wss://')}/api/v1/ai/live';
    } else {
      return '${baseUrl.replaceFirst('http://', 'ws://')}/api/v1/ai/live';
    }
  }

  Future<void> startLiveSession() async {
    if (_isLive) return;

    try {
      _isMuted = false;
      _setState(LiveSessionState.connecting);
      debugPrint("DEBUG: Starting Live Session...");

      // 2. Setup WebSocket Connection
      debugPrint("DEBUG: Getting access token...");
      final token = await authService.getToken() ?? '';
      
      final uri = Uri.parse('$_wsUrl?token=$token');
      debugPrint("DEBUG: Connecting to WebSocket $uri...");
      _channel = WebSocketChannel.connect(uri);
      
      try {
        debugPrint("DEBUG: Awaiting WebSocket ready state...");
        await _channel!.ready;
        debugPrint("DEBUG: WebSocket connected successfully!");
      } catch (e) {
        debugPrint("DEBUG: WebSocket connection failed: $e");
        rethrow;
      }

      // Listen to incoming WebSocket messages from Gemini
      _wsSub = _channel?.stream.listen((message) {
        _handleIncomingMessage(message);
      }, onError: (error) {
        debugPrint("WebSocket Error: $error");
        stopLiveSession();
      }, onDone: () {
        debugPrint("WebSocket Closed");
        stopLiveSession();
      });

      // 3. Start Recording Audio (16kHz, 16-bit PCM Mono)
      debugPrint("DEBUG: Checking microphone permission...");
      if (await _audioRecorder.hasPermission()) {
        debugPrint("DEBUG: Starting audio recorder stream...");
        final recordStream = await _audioRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: _sampleRateInput,
            numChannels: 1,
          ),
        );

        _recordSub = recordStream.listen((data) {
          // Calculate basic amplitude (RMS) from 16-bit PCM for the UI
          if (!_isMuted) {
            double sum = 0;
            final int16List = Int16List.view(data.buffer);
            for (int i = 0; i < int16List.length; i++) {
              sum += int16List[i] * int16List[i];
            }
            double rms = sqrt(sum / int16List.length) / 32768.0;
            _amplitudeController.add(rms);
          }

          if (_channel != null && _channel!.closeCode == null && !_isMuted) {
            // Send raw bytes to the backend
            _channel!.sink.add(data);
          }
        });
        debugPrint("DEBUG: Audio recorder stream started.");
      } else {
        throw Exception("Microphone permission denied");
      }

      _isLive = true;
      _setState(LiveSessionState.listening);
      debugPrint("DEBUG: Live session fully started.");
    } catch (e) {
      debugPrint("Error starting live session: $e");
      stopLiveSession();
    }
  }

  final _transcriptController = StreamController<String>.broadcast();
  Stream<String> get transcriptStream => _transcriptController.stream;

  void _handleIncomingMessage(dynamic message) {
    if (message is String) {
      try {
        final data = jsonDecode(message);
        
        // Extract serverContent modelTurn from Gemini response
        if (data.containsKey('serverContent') && 
            data['serverContent'].containsKey('modelTurn')) {
          
          final parts = data['serverContent']['modelTurn']['parts'];
          if (parts != null && parts.isNotEmpty) {
            for (var part in parts) {
              if (part.containsKey('text')) {
                final text = part['text'];
                if (text != null && text.isNotEmpty) {
                  // Broadcast text to UI
                  _transcriptController.add(text);
                  // Speak text natively
                  _flutterTts.speak(text);
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Error parsing Gemini response: $e");
      }
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      _setState(LiveSessionState.paused);
      _amplitudeController.add(0.0);
    } else {
      _setState(LiveSessionState.listening);
    }
  }

  bool _isBackgroundPaused = false;

  Future<void> handleAppBackground() async {
    if (!_isLive || _isBackgroundPaused) return;
    debugPrint("DEBUG: App going to background. Suspending microphone...");
    _isBackgroundPaused = true;
    
    // Stop recording stream to release microphone
    await _recordSub?.cancel();
    _recordSub = null;
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
    _amplitudeController.add(0.0);
    _setState(LiveSessionState.paused);
  }

  Future<void> handleAppForeground() async {
    if (!_isLive || !_isBackgroundPaused) return;
    debugPrint("DEBUG: App returning to foreground. Resuming microphone...");
    _isBackgroundPaused = false;

    if (!_isMuted) {
      if (await _audioRecorder.hasPermission()) {
        final recordStream = await _audioRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: _sampleRateInput,
            numChannels: 1,
          ),
        );

        _recordSub = recordStream.listen((data) {
          if (!_isMuted) {
            double sum = 0;
            final int16List = Int16List.view(data.buffer);
            for (int i = 0; i < int16List.length; i++) {
              sum += int16List[i] * int16List[i];
            }
            double rms = sqrt(sum / int16List.length) / 32768.0;
            _amplitudeController.add(rms);
          }

          if (_channel != null && _channel!.closeCode == null && !_isMuted) {
            _channel!.sink.add(data);
          }
        });
      }
      _setState(LiveSessionState.listening);
    }
  }

  Future<void> stopLiveSession() async {
    _isLive = false;
    _isBackgroundPaused = false;
    _setState(LiveSessionState.disconnected);
    _amplitudeController.add(0.0);
    
    // Stop recording
    await _recordSub?.cancel();
    _recordSub = null;
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }

    // Stop playback
    await _flutterTts.stop();

    // Close WebSocket
    await _wsSub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}

// Global instance for easy access
final liveAudioService = LiveAudioService();

// Make from Kiên and Dương with love
