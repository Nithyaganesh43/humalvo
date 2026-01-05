import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'websocket_service.dart';
import 'device_provider.dart';
import 'voicecontrol_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _fanRotationController;
  late AnimationController _pumpWaterController;
  
  // IP Configuration
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  bool _showIPConfig = false;

  @override
  void initState() {
    super.initState();
    
    _fanRotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _pumpWaterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _setupWebSocket();
    _loadSavedIP();
  }

  @override
  void dispose() {
    _fanRotationController.dispose();
    _pumpWaterController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedIP() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIP = prefs.getString('ai_server_ip') ?? '192.168.1.6';
    final savedPort = prefs.getString('ai_server_port') ?? '5000';
    
    setState(() {
      _ipController.text = savedIP;
      _portController.text = savedPort;
    });
  }

  Future<void> _saveIP() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_server_ip', _ipController.text.trim());
    await prefs.setString('ai_server_port', _portController.text.trim());
    
    Navigator.pop(context); // Close dialog
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ AI Server IP saved!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showIPConfigDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.computer,
                        color: Colors.orange[700],
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'AI Server Configuration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Info Text
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Configure your AI server IP address',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // IP Address Input
                TextField(
                  controller: _ipController,
                  decoration: InputDecoration(
                    labelText: 'IP Address',
                    hintText: '192.168.1.6',
                    prefixIcon: const Icon(Icons.dns),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                
                // Port Input
                TextField(
                  controller: _portController,
                  decoration: InputDecoration(
                    labelText: 'Port',
                    hintText: '5000',
                    prefixIcon: const Icon(Icons.settings_ethernet),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                
                // Current Config Display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'http://${_ipController.text.isEmpty ? "___" : _ipController.text}:${_portController.text.isEmpty ? "____" : _portController.text}/predict',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveIP,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _setupWebSocket() {
    final wsService = context.read<WebSocketService>();
    final deviceProvider = context.read<DeviceProvider>();

    wsService.messageStream.listen((message) {
      deviceProvider.applyCommand(message);
    });

    wsService.statusStream.listen((status) {
      String statusText;
      bool isConnected = false;

      switch (status) {
        case ConnectionStatus.connecting:
          statusText = 'Connecting...';
          break;
        case ConnectionStatus.connected:
          statusText = 'Connected';
          isConnected = true;
          break;
        case ConnectionStatus.disconnected:
          statusText = 'Disconnected';
          break;
        case ConnectionStatus.error:
          statusText = 'Connection Error';
          break;
      }

      deviceProvider.updateConnectionStatus(isConnected, statusText);
    });
  }

  void _toggleDevice(String device) {
    final deviceProvider = context.read<DeviceProvider>();
    final wsService = context.read<WebSocketService>();
    
    if (!deviceProvider.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect to ESP32 first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final command = deviceProvider.getToggleCommand(device);
    wsService.sendCommand(command);
    
    if (device == 'fan') {
      if (deviceProvider.state.fan) {
        _fanRotationController.repeat();
      } else {
        _fanRotationController.stop();
        _fanRotationController.reset();
      }
    } else if (device == 'pump') {
      if (deviceProvider.state.pump) {
        _pumpWaterController.repeat();
      } else {
        _pumpWaterController.stop();
        _pumpWaterController.reset();
      }
    }
  }

  void _turnOffAll() async {
    final deviceProvider = context.read<DeviceProvider>();
    final wsService = context.read<WebSocketService>();
    
    if (!deviceProvider.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect to ESP32 first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    print('🔴 Turn Off All pressed');
    wsService.sendCommand('024');
    print('📤 Sent command: 024 (Light OFF, Fan OFF, Pump OFF)');
    
    _fanRotationController.stop();
    _fanRotationController.reset();
    _pumpWaterController.stop();
    _pumpWaterController.reset();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All devices turned OFF'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Control Panel',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.normal,
          ),
        ),
        actions: [
          // IP Config Button
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.settings,
                color: Colors.orange,
                size: 24,
              ),
            ),
            onPressed: () {
              _showIPConfigDialog();
            },
            tooltip: 'AI Server Config',
          ),
          // Voice Control Button
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic,
                color: Colors.blue,
                size: 24,
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VoiceControlPage(),
                ),
              );
            },
            tooltip: 'Voice Control',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey[300],
            height: 1,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const VoiceControlPage(),
            ),
          );
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.mic, color: Colors.white, size: 28),
        tooltip: 'Voice Control',
      ),
      body: SafeArea(
        child: Consumer<DeviceProvider>(
          builder: (context, deviceProvider, _) {
            // Control fan animation
            if (deviceProvider.state.fan) {
              if (!_fanRotationController.isAnimating) {
                _fanRotationController.repeat();
              }
            } else {
              _fanRotationController.stop();
              _fanRotationController.reset();
            }
            
            // Control pump animation
            if (deviceProvider.state.pump) {
              if (!_pumpWaterController.isAnimating) {
                _pumpWaterController.repeat();
              }
            } else {
              _pumpWaterController.stop();
              _pumpWaterController.reset();
            }
            
            return Column(
              children: [
                const SizedBox(height: 20),
                _buildConnectionStatus(deviceProvider),
                const SizedBox(height: 20),
                _buildDeviceGrid(deviceProvider),
                const SizedBox(height: 30),
                _buildOffAllButton(deviceProvider),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildIPConfigBox() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.computer, color: Colors.orange[700], size: 20),
              const SizedBox(width: 8),
              const Text(
                'AI Server Configuration',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  setState(() {
                    _showIPConfig = false;
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // IP Address Input
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _ipController,
                  decoration: InputDecoration(
                    labelText: 'IP Address',
                    hintText: '192.168.1.6',
                    prefixIcon: const Icon(Icons.dns, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _portController,
                  decoration: InputDecoration(
                    labelText: 'Port',
                    hintText: '5000',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveIP,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Save Configuration'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Current Config Display
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Current: http://${_ipController.text}:${_portController.text}/predict',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(DeviceProvider deviceProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: deviceProvider.isConnected ? Colors.green[100] : Colors.red[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: deviceProvider.isConnected ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            deviceProvider.connectionStatus.toUpperCase(),
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceGrid(DeviceProvider deviceProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildDeviceCard(
            title: 'Light',
            icon: Icons.lightbulb_outline,
            isOn: deviceProvider.state.light,
            onTap: () => _toggleDevice('light'),
            isEnabled: deviceProvider.isConnected,
            deviceType: DeviceType.light,
          ),
          _buildDeviceCard(
            title: 'Fan',
            icon: Icons.toys_outlined,
            isOn: deviceProvider.state.fan,
            onTap: () => _toggleDevice('fan'),
            isEnabled: deviceProvider.isConnected,
            deviceType: DeviceType.fan,
          ),
          _buildDeviceCard(
            title: 'Pump',
            icon: Icons.water_drop_outlined,
            isOn: deviceProvider.state.pump,
            onTap: () => _toggleDevice('pump'),
            isEnabled: deviceProvider.isConnected,
            deviceType: DeviceType.pump,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard({
    required String title,
    required IconData icon,
    required bool isOn,
    required VoidCallback onTap,
    required bool isEnabled,
    required DeviceType deviceType,
  }) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: _buildDeviceIcon(deviceType, isOn, icon),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: isEnabled ? onTap : null,
          child: Container(
            width: 100,
            height: 40,
            decoration: BoxDecoration(
              color: isOn ? Colors.green : Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isOn ? Colors.green[700]! : Colors.grey[400]!,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                isOn ? 'ON' : 'OFF',
                style: TextStyle(
                  color: isOn ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceIcon(DeviceType deviceType, bool isOn, IconData icon) {
    switch (deviceType) {
      case DeviceType.light:
        return Icon(
          isOn ? Icons.lightbulb : Icons.lightbulb_outline,
          size: 60,
          color: isOn ? Colors.blue : Colors.grey,
        );
      
      case DeviceType.fan:
        return AnimatedBuilder(
          animation: _fanRotationController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _fanRotationController.value * 2 * math.pi,
              child: CustomPaint(
                size: const Size(70, 70),
                painter: FanBladePainter(
                  color: isOn ? Colors.blue : Colors.grey,
                ),
              ),
            );
          },
        );
      
      case DeviceType.pump:
        return AnimatedBuilder(
          animation: _pumpWaterController,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(70, 70),
              painter: WaterPumpPainter(
                color: isOn ? Colors.blue : Colors.grey,
                animationValue: _pumpWaterController.value,
                isOn: isOn,
              ),
            );
          },
        );
    }
  }

  Widget _buildOffAllButton(DeviceProvider deviceProvider) {
    final anyDeviceOn = deviceProvider.state.light || 
                       deviceProvider.state.fan || 
                       deviceProvider.state.pump;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: ElevatedButton(
        onPressed: (anyDeviceOn && deviceProvider.isConnected) ? _turnOffAll : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: anyDeviceOn ? Colors.red : Colors.grey[300],
          disabledBackgroundColor: Colors.grey[300],
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: Text(
          'TURN OFF ALL',
          style: TextStyle(
            color: anyDeviceOn ? Colors.white : Colors.grey[600],
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

enum DeviceType { light, fan, pump }

// Custom painter for fan blades
class FanBladePainter extends CustomPainter {
  final Color color;

  FanBladePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final bladeLength = size.width * 0.4;
    final bladeWidth = size.width * 0.15;

    for (int i = 0; i < 3; i++) {
      final angle = (i * 120) * math.pi / 180;
      
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      final bladePath = Path();
      bladePath.addOval(
        Rect.fromCenter(
          center: Offset(bladeLength / 2, 0),
          width: bladeLength,
          height: bladeWidth,
        ),
      );
      
      canvas.drawPath(bladePath, paint);
      canvas.restore();
    }

    canvas.drawCircle(
      center,
      size.width * 0.12,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for hand pump
class WaterPumpPainter extends CustomPainter {
  final Color color;
  final double animationValue;
  final bool isOn;

  WaterPumpPainter({
    required this.color,
    required this.animationValue,
    required this.isOn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final bodyWidth = size.width * 0.2;
    final bodyHeight = size.height * 0.5;
    
    for (int i = 0; i < 3; i++) {
      final segmentY = center.dy - 5 + (i * 8);
      final segmentRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, segmentY),
          width: bodyWidth,
          height: 7,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(segmentRect, paint);
    }
    
    final spoutPath = Path();
    spoutPath.moveTo(center.dx - bodyWidth / 2, center.dy - 8);
    spoutPath.lineTo(center.dx - bodyWidth / 2 - 10, center.dy - 8);
    spoutPath.lineTo(center.dx - bodyWidth / 2 - 10, center.dy + 5);
    spoutPath.lineTo(center.dx - bodyWidth / 2 - 15, center.dy + 5);
    canvas.drawPath(spoutPath, strokePaint);
    
    final handlePath = Path();
    handlePath.moveTo(center.dx + bodyWidth / 2, center.dy - 5);
    handlePath.quadraticBezierTo(
      center.dx + size.width * 0.35, center.dy - 25,
      center.dx + size.width * 0.25, center.dy - 30,
    );
    
    final handleOffset = isOn ? math.sin(animationValue * 2 * math.pi) * 5 : 0;
    handlePath.quadraticBezierTo(
      center.dx + size.width * 0.2, center.dy - 32 + handleOffset,
      center.dx + size.width * 0.2, center.dy - 20 + handleOffset,
    );
    
    canvas.drawPath(handlePath, strokePaint);
    
    canvas.drawCircle(
      Offset(center.dx + size.width * 0.2, center.dy - 20 + handleOffset),
      4,
      paint,
    );
    
    final basePath = Path();
    basePath.moveTo(center.dx - size.width * 0.25, center.dy + 20);
    basePath.lineTo(center.dx - size.width * 0.25, center.dy + 24);
    basePath.lineTo(center.dx + size.width * 0.25, center.dy + 24);
    basePath.lineTo(center.dx + size.width * 0.25, center.dy + 20);
    canvas.drawPath(basePath, paint);
    
    if (isOn) {
      final waterPaint = Paint()
        ..color = Colors.blue.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      
      final waterPath = Path();
      final spoutEndX = center.dx - bodyWidth / 2 - 15;
      final spoutEndY = center.dy + 5;
      
      waterPath.moveTo(spoutEndX, spoutEndY);
      
      for (int i = 0; i < 6; i++) {
        final progress = (i / 5.0);
        final flowOffset = ((animationValue + progress) % 1.0);
        
        if (flowOffset < 0.8) {
          final x = spoutEndX - (progress * 8);
          final y = spoutEndY + (progress * progress * 20);
          
          canvas.drawCircle(
            Offset(x, y),
            2.5 - (progress * 0.5),
            Paint()
              ..color = Colors.blue.withOpacity(0.8 - (progress * 0.3))
              ..style = PaintingStyle.fill,
          );
        }
      }
      
      final splashY = center.dy + 25;
      final splashX = spoutEndX - 8;
      
      for (int i = 0; i < 3; i++) {
        final splashOffset = ((animationValue * 2 + i * 0.3) % 1.0);
        if (splashOffset < 0.5) {
          final splashPaint = Paint()
            ..color = Colors.blue.withOpacity(0.5 - splashOffset)
            ..style = PaintingStyle.fill;
          
          canvas.drawCircle(
            Offset(splashX + (i - 1) * 4, splashY - splashOffset * 3),
            2.0,
            splashPaint,
          );
        }
      }
      
      final puddlePaint = Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(splashX, splashY + 2),
          width: 12,
          height: 4,
        ),
        puddlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(WaterPumpPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || 
           oldDelegate.isOn != isOn ||
           oldDelegate.color != color;
  }
}