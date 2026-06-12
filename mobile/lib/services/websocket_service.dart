import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';


import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

class WebSocketService {
  static WebSocketService? _instance;
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController = StreamController.broadcast();
  bool _isConnected = false;
  Timer? _reconnectTimer;
  String? _wsUrl;

  // Singleton
  static WebSocketService get instance {
    _instance ??= WebSocketService._();
    return _instance!;
  }

  WebSocketService._();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  Future<void> connect() async {
    if (_isConnected) return;

    try {
      final token = await ApiService.getToken();
      final parentId = await ApiService.getParentId();
      
      if (token == null || parentId == null) {
        debugPrint('WS: Impossible de se connecter - Token ou parentId manquant');
        return;
      }

      // Constuire l'URL WebSocket à partir de l'URL de base API
      final uri = Uri.parse(ApiService.baseUrl);
      final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final portString = (uri.hasPort && uri.port != 80 && uri.port != 443) ? ':${uri.port}' : '';
      _wsUrl = '$wsScheme://${uri.host}$portString/api/ws/$parentId?token=$token';

      debugPrint('WS: Connexion à $_wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl!));
      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            _messageController.add(data);
          } catch (e) {
            debugPrint('WS Erreur parsing: $e');
          }
        },
        onDone: () {
          debugPrint('WS: Déconnecté');
          _isConnected = false;
          _scheduleReconnect();
        },
        onError: (error) {
          debugPrint('WS Erreur: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('WS: Échec de connexion - $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('WS: Tentative de reconnexion...');
      connect();
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }
}
