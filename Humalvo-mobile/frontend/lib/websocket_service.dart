import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  // ⚙️ SET YOUR ESP32 IP ADDRESS HERE ⚙️
  static const String ESP32_IP = "192.168.132.207";  // ← CHANGE THIS
  static const int ESP32_PORT = 81;
  
  // GPIO Pins (for reference - matches ESP32 code):
  // Light: GPIO 26
  // Fan:   GPIO 27
  // Pump:  GPIO 12
  
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _isConnecting = false;
  bool _isManualDisconnect = false;
  DateTime? _lastMessageTime;
  
  final _messageController = StreamController<String>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  
  Stream<String> get messageStream => _messageController.stream;
  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  
  WebSocketService() {
    connect();
    _startHeartbeatMonitor();
  }
  
  void connect() {
    if (_isConnecting) return;
    
    _isConnecting = true;
    _isManualDisconnect = false;
    _statusController.add(ConnectionStatus.connecting);
    
    try {
      final uri = Uri.parse('ws://$ESP32_IP:$ESP32_PORT');
      print('🔌 Connecting to: $uri');
      
      _channel = WebSocketChannel.connect(
        uri,
        // Add connection timeout
      );
      
      // Set connection timeout
      Timer(const Duration(seconds: 5), () {
        if (_isConnecting) {
          print('⏱️ Connection timeout');
          _handleError();
        }
      });
      
      _channel!.stream.listen(
        (message) {
          print('📥 Received: $message');
          _lastMessageTime = DateTime.now();
          _statusController.add(ConnectionStatus.connected);
          _messageController.add(message.toString());
        },
        onError: (error) {
          print('❌ Stream error: $error');
          _handleError();
        },
        onDone: () {
          print('🔌 Stream closed - ESP32 disconnected');
          _handleDisconnect();
        },
        cancelOnError: false,
      );
      
      // Send initial status request after connection
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_isManualDisconnect && _channel != null) {
          sendCommand('S');
          _lastMessageTime = DateTime.now();
          _isConnecting = false;
        }
      });
      
    } catch (e) {
      print('💥 Connection exception: $e');
      _handleError();
    }
  }
  
  void _startHeartbeatMonitor() {
    // Check connection health every 2 seconds
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_lastMessageTime != null) {
        final timeSinceLastMessage = DateTime.now().difference(_lastMessageTime!);
        
        // If no message received in 4 seconds, consider disconnected
        if (timeSinceLastMessage.inSeconds > 4) {
          print('⚠️ No message in ${timeSinceLastMessage.inSeconds}s - Connection lost');
          _handleDisconnect();
        } else {
          // Send heartbeat to keep connection alive
          sendCommand('S');
        }
      }
    });
  }
  
  void _handleError() {
    _isConnecting = false;
    _statusController.add(ConnectionStatus.error);
    _closeConnection();
    
    if (!_isManualDisconnect) {
      _scheduleReconnect();
    }
  }
  
  void _handleDisconnect() {
    _isConnecting = false;
    _statusController.add(ConnectionStatus.disconnected);
    _closeConnection();
    
    if (!_isManualDisconnect) {
      _scheduleReconnect();
    }
  }
  
  void _closeConnection() {
    try {
      _channel?.sink.close(status.normalClosure);
    } catch (e) {
      print('Error closing channel: $e');
    }
    _channel = null;
    _lastMessageTime = null;
  }
  
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_isManualDisconnect) {
        print('🔄 Attempting reconnection...');
        connect();
      }
    });
  }
  
  void sendCommand(String command) {
    if (_channel != null) {
      try {
        print('📤 Sending: $command');
        _channel!.sink.add(command);
        _lastMessageTime = DateTime.now();
      } catch (e) {
        print('❌ Send error: $e');
        // Immediately handle disconnect if send fails
        _handleDisconnect();
      }
    } else {
      print('⚠️ Cannot send command - not connected');
    }
  }
  
  void dispose() {
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _closeConnection();
    _messageController.close();
    _statusController.close();
  }
}

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}