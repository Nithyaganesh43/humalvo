import 'package:flutter/foundation.dart';

class DeviceState {
  bool light;
  bool fan;
  bool pump;

  DeviceState({
    this.light = false,
    this.fan = false,
    this.pump = false,
  });
}

class DeviceProvider extends ChangeNotifier {
  DeviceState _state = DeviceState();
  bool _isConnected = false;
  String _connectionStatus = 'Connecting...';

  DeviceState get state => _state;
  bool get isConnected => _isConnected;
  String get connectionStatus => _connectionStatus;

  void updateConnectionStatus(bool connected, String status) {
    _isConnected = connected;
    _connectionStatus = status;
    notifyListeners();
  }

  void applyCommand(String command) {
    bool changed = false;
    
    print('📥 Processing command: $command');
    
    for (int i = 0; i < command.length; i++) {
      switch (command[i]) {
        case '0':
          if (_state.light != false) {
            _state.light = false;
            changed = true;
            print('💡 Light: OFF');
          }
          break;
        case '1':
          if (_state.light != true) {
            _state.light = true;
            changed = true;
            print('💡 Light: ON');
          }
          break;
        case '2':
          if (_state.fan != false) {
            _state.fan = false;
            changed = true;
            print('🌀 Fan: OFF');
          }
          break;
        case '3':
          if (_state.fan != true) {
            _state.fan = true;
            changed = true;
            print('🌀 Fan: ON');
          }
          break;
        case '4':
          if (_state.pump != false) {
            _state.pump = false;
            changed = true;
            print('💧 Pump: OFF');
          }
          break;
        case '5':
          if (_state.pump != true) {
            _state.pump = true;
            changed = true;
            print('💧 Pump: ON');
          }
          break;
        case 'S':
        case 's':
          // Ignore status request characters
          break;
        default:
          print('⚠️ Unknown command character: ${command[i]}');
      }
    }
    
    if (changed) {
      print('✅ State updated: Light=${_state.light}, Fan=${_state.fan}, Pump=${_state.pump}');
      notifyListeners();
    }
  }

  String getToggleCommand(String device) {
    String command = '';
    
    switch (device) {
      case 'light':
        command = _state.light ? '0' : '1';
        print('📤 Toggle Light: ${_state.light ? "ON→OFF" : "OFF→ON"} (sending: $command)');
        break;
      case 'fan':
        command = _state.fan ? '2' : '3';
        print('📤 Toggle Fan: ${_state.fan ? "ON→OFF" : "OFF→ON"} (sending: $command)');
        break;
      case 'pump':
        command = _state.pump ? '4' : '5';
        print('📤 Toggle Pump: ${_state.pump ? "ON→OFF" : "OFF→ON"} (sending: $command)');
        break;
      default:
        print('❌ Unknown device: $device');
    }
    
    return command;
  }
}