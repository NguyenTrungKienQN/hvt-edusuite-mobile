// ignore_for_file: avoid_print
import 'dart:io';

void main() async {
  try {
    var uri = Uri.parse('wss://hvtapi.io.vn/api/v1/ai/live');
    print('URI port: ${uri.port}, scheme: ${uri.scheme}');
    await WebSocket.connect(uri.toString());
  } catch (e) {
    print('Error: $e');
  }
}
