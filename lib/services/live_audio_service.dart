import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:record/record.dart';
import 'package:sound_stream/sound_stream.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';

class LiveAudioService {
  WebSocketChannel? _channel;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final PlayerStream _playerStream = PlayerStream();
  final FlutterTts _flutterTts = FlutterTts();
  
  StreamSubscription? _recordSub;
  StreamSubscription? _wsSub;

  bool _isLive = false;
  bool get isLive => _isLive;

  // Configuration
  static const int _sampleRateInput = 16000;
  static const int _sampleRateOutput = 24000;
  final String _wsUrl = 'ws://127.0.0.1:8000/api/v1/ai/live'; // To be replaced with actual env url

  Future<void> startLiveSession() async {
    if (_isLive) return;

    try {
      // 1. Initialize Audio Player
      await _playerStream.initialize(sampleRate: _sampleRateOutput);
      await _playerStream.start();

      // 2. Setup WebSocket Connection
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      
      final uri = Uri.parse('$_wsUrl?token=$token');
      _channel = WebSocketChannel.connect(uri);

      // Listen to incoming WebSocket messages from Gemini
      _wsSub = _channel?.stream.listen((message) {
        _handleIncomingMessage(message);
      }, onError: (error) {
        print("WebSocket Error: $error");
        stopLiveSession();
      }, onDone: () {
        print("WebSocket Closed");
        stopLiveSession();
      });

      // 3. Start Recording Audio (16kHz, 16-bit PCM Mono)
      if (await _audioRecorder.hasPermission()) {
        final recordStream = await _audioRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: _sampleRateInput,
            numChannels: 1,
          ),
        );

        _recordSub = recordStream.listen((data) {
          if (_channel != null && _channel!.closeCode == null) {
            // Send raw bytes to the backend
            _channel!.sink.add(data);
          }
        });
      } else {
        throw Exception("Microphone permission denied");
      }

      _isLive = true;
    } catch (e) {
      print("Error starting live session: $e");
      stopLiveSession();
    }
  }

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
                  // Speak text natively
                  _flutterTts.speak(text);
                }
              }
            }
          }
        }
      } catch (e) {
        print("Error parsing Gemini response: $e");
      }
    }
  }

  Future<void> stopLiveSession() async {
    _isLive = false;
    
    // Stop recording
    await _recordSub?.cancel();
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }

    // Stop playback
    await _playerStream.stop();
    await _flutterTts.stop();

    // Close WebSocket
    await _wsSub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}

// Global instance for easy access
final liveAudioService = LiveAudioService();
