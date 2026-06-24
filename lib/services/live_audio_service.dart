import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:record/record.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'api_service.dart';
import 'auth_service.dart';

enum LiveSessionState { disconnected, connecting, listening, aiSpeaking, paused }

class LiveAudioService {
  WebSocketChannel? _channel;
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  StreamSubscription? _recordSub;
  StreamSubscription? _wsSub;
  
  // Audio player for raw PCM from Gemini (24kHz)
  FlutterSoundPlayer? _audioPlayer;
  StreamController<Uint8List>? _audioStreamController;

  final _stateController = StreamController<LiveSessionState>.broadcast();
  Stream<LiveSessionState> get stateStream => _stateController.stream;

  final _amplitudeController = StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  final _transcriptController = StreamController<String>.broadcast();
  Stream<String> get transcriptStream => _transcriptController.stream;

  LiveSessionState _currentState = LiveSessionState.disconnected;
  LiveSessionState get currentState => _currentState;

  bool _isMuted = false;
  bool get isMuted => _isMuted;
  
  bool _isLive = false;
  bool get isLive => _isLive;

  void _setState(LiveSessionState state) {
    if (_currentState != state) {
      _currentState = state;
      _stateController.add(state);
    }
  }

  // Configuration
  static const int _sampleRateInput = 16000;
  static const int _sampleRateOutput = 24000; // Gemini outputs 24kHz
  
  String get _wsUrl {
    final baseUrl = apiService.baseUrl;
    if (baseUrl.startsWith('https://')) {
      return '${baseUrl.replaceFirst('https://', 'wss://')}/api/v1/ai/live';
    } else {
      return '${baseUrl.replaceFirst('http://', 'ws://')}/api/v1/ai/live';
    }
  }

  Future<void> _initAudioPlayer() async {
    _audioPlayer = FlutterSoundPlayer();
    await _audioPlayer!.openPlayer();
  }

  Future<void> startLiveSession() async {
    if (_isLive) return;

    try {
      _isMuted = false;
      _setState(LiveSessionState.connecting);
      debugPrint("DEBUG: Starting Live Session...");

      // Init audio player for Gemini responses
      await _initAudioPlayer();

      // Setup WebSocket Connection
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

      // Listen to incoming WebSocket messages from backend
      _wsSub = _channel?.stream.listen((message) {
        _handleIncomingMessage(message);
      }, onError: (error) {
        debugPrint("WebSocket Error: $error");
        stopLiveSession();
      }, onDone: () {
        debugPrint("WebSocket Closed");
        stopLiveSession();
      });

      // Start Recording Audio (16kHz, 16-bit PCM Mono)
      debugPrint("DEBUG: Checking microphone permission...");
      if (await _audioRecorder.hasPermission()) {
        debugPrint("DEBUG: Starting audio recorder stream...");
        final recordStream = await _audioRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: _sampleRateInput,
            numChannels: 1,
            echoCancel: true,
            noiseSuppress: true,
            autoGain: true,
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

  void _handleIncomingMessage(dynamic message) {
    if (message is Uint8List) {
      // Binary frame = raw PCM audio from Gemini (24kHz 16-bit mono)
      _playAudioChunk(message);
    } else if (message is List<int>) {
      // Also binary but as List<int>
      _playAudioChunk(Uint8List.fromList(message));
    } else if (message is String) {
      try {
        final data = jsonDecode(message);
        
        // Text transcript from Gemini
        if (data.containsKey('serverContent') && 
            data['serverContent'].containsKey('modelTurn')) {
          
          final parts = data['serverContent']['modelTurn']['parts'];
          if (parts != null && parts.isNotEmpty) {
            for (var part in parts) {
              if (part.containsKey('text')) {
                final text = part['text'];
                if (text != null && text.isNotEmpty) {
                  // Disabled: Backend is currently sending model "thinking text" instead of conversational text.
                  // We now handle the UI by showing an "AI đang nói..." state instead.
                  // _transcriptController.add(text);
                }
              }
            }
          }
        }
        
        // turnComplete signal
        if (data.containsKey('serverContent') &&
            data['serverContent']['turnComplete'] == true) {
          debugPrint("DEBUG: Gemini turn complete");
          // Small delay then switch back to listening
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_isLive && !_isMuted) {
              _setState(LiveSessionState.listening);
            } else if (_isLive && _isMuted) {
              _setState(LiveSessionState.paused);
            }
          });
        }
      } catch (e) {
        debugPrint("Error parsing response: $e");
      }
    }
  }

  bool _isPlayingAudio = false;

  void _playAudioChunk(Uint8List pcmData) {
    if (!_isLive) return;
    _setState(LiveSessionState.aiSpeaking);
    
    // Feed audio directly to player
    _feedAudioToPlayer(pcmData);
  }

  Future<void> _feedAudioToPlayer(Uint8List pcmData) async {
    if (_audioPlayer == null) return;
    
    try {
      if (!_isPlayingAudio) {
        _isPlayingAudio = true;
        
        // Start a streaming player session
        _audioStreamController = StreamController<Uint8List>();
        
        // Start playing from the stream
        await _audioPlayer!.startPlayerFromStream(
          codec: Codec.pcm16,
          sampleRate: _sampleRateOutput,
          numChannels: 1,
          interleaved: true,
          bufferSize: 8192,
        );
      }
      
      // Feed the chunk
      _audioPlayer!.uint8ListSink?.add(pcmData);
    } catch (e) {
      debugPrint("Error playing audio: $e");
      _isPlayingAudio = false;
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
    _isPlayingAudio = false;
    _setState(LiveSessionState.disconnected);
    _amplitudeController.add(0.0);
    
    // Stop recording
    await _recordSub?.cancel();
    _recordSub = null;
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }

    // Stop audio player
    try {
      if (_audioPlayer != null && _audioPlayer!.isPlaying) {
        await _audioPlayer!.stopPlayer();
      }
      await _audioPlayer?.closePlayer();
      _audioPlayer = null;
    } catch (e) {
      debugPrint("Error stopping audio player: $e");
    }
    
    _audioStreamController?.close();
    _audioStreamController = null;

    // Close WebSocket
    await _wsSub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}

// Global instance for easy access
final liveAudioService = LiveAudioService();

// Make from Kiên and Dương with love
