import 'package:flutter/material.dart';
import '../services/live_audio_service.dart';

class AiLiveScreen extends StatefulWidget {
  const AiLiveScreen({super.key});

  @override
  State<AiLiveScreen> createState() => _AiLiveScreenState();
}

class _AiLiveScreenState extends State<AiLiveScreen> {
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _startLive();
  }

  Future<void> _startLive() async {
    setState(() => _isConnecting = true);
    await liveAudioService.startLiveSession();
    if (mounted) {
      setState(() => _isConnecting = false);
    }
  }

  Future<void> _stopLiveAndExit() async {
    await liveAudioService.stopLiveSession();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    liveAudioService.stopLiveSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A), // Dark theme
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32),
                    onPressed: _stopLiveAndExit,
                  ),
                  const Text(
                    'Gemini Live',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 48), // Balance for back button
                ],
              ),
            ),
            
            const Spacer(),

            // Status Text
            Text(
              _isConnecting ? 'Connecting...' : (liveAudioService.isLive ? 'Listening...' : 'Disconnected'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            
            const Spacer(),
            
            // Bottom Controls & Visualizer Placeholder
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1A1A1A),
                    Colors.blue.withValues(alpha: 0.2),
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // TODO: Mobile Team will add the glowing wave animation here
                  const Text(
                    '[ Wave Animation UI Placeholder ]',
                    style: TextStyle(color: Colors.white38),
                  ),
                  
                  // Controls
                  Positioned(
                    bottom: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Pause Button
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.pause, color: Colors.white),
                            onPressed: () {
                              // TODO: Implement pause logic
                            },
                          ),
                        ),
                        
                        // End Call Button
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.call_end, color: Colors.white),
                            onPressed: _stopLiveAndExit,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
