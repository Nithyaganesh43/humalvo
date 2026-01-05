

import 'package:flutter/material.dart';
import 'voice_assistant_controller.dart';

class VoiceControlPage extends StatefulWidget {
  const VoiceControlPage({super.key});

  @override
  State<VoiceControlPage> createState() => _VoiceControlPageState();
}

class _VoiceControlPageState extends State<VoiceControlPage> {
  late VoiceAssistantController _controller;
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = VoiceAssistantController();
    _controller.addListener(_onControllerUpdate);
    _initializeController();
  }

  Future<void> _initializeController() async {
    await _controller.initialize();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showNameDialog() {
    _nameController.text = _controller.assistantName;
    bool isDialogActive = true; // Track if dialog is still active

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Safe setState that checks if dialog is still active
          void safeSetState() {
            if (isDialogActive && mounted) {
              setDialogState(() {});
            }
          }

          // Listen to controller updates
          void updateDialog() {
            safeSetState();
          }

          _controller.addListener(updateDialog);

          return WillPopScope(
            onWillPop: () async {
              isDialogActive = false;
              _controller.removeListener(updateDialog);
              _controller.cancelVoiceNaming();
              return true;
            },
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.home, color: Colors.blue[700]),
                  const SizedBox(width: 10),
                  Text(_controller.hasAssistantName ? 'Rename Assistant' : 'Name Your Assistant'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _controller.hasAssistantName
                        ? 'Change your assistant\'s name'
                        : 'Choose a name for your voice assistant',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Text input field
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    enabled: !_controller.isNaming,
                    decoration: InputDecoration(
                      hintText: 'e.g., World, Jarvis, Alex',
                      prefixIcon: const Icon(Icons.edit),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                      ),
                    ),
                    onSubmitted: (_) => _saveTextName(isDialogActive, _controller.removeListener, updateDialog),
                  ),

                  const SizedBox(height: 16),

                  // OR divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[400])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ),
                      Expanded(child: Divider(color: Colors.grey[400])),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Voice input button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        if (_controller.isNaming) {
                          await _controller.cancelVoiceNaming();
                        } else {
                          _nameController.clear();
                          await _controller.startVoiceNaming();
                        }
                        safeSetState();
                      },
                      icon: Icon(
                        _controller.isNaming ? Icons.stop : Icons.mic,
                        color: _controller.isNaming ? Colors.red : Colors.blue[700],
                      ),
                      label: Text(
                        _controller.isNaming ? 'Stop Listening' : 'Say Name with Voice',
                        style: TextStyle(
                          color: _controller.isNaming ? Colors.red : Colors.blue[700],
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: _controller.isNaming ? Colors.red : Colors.blue[700]!,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  // Show current listening text
                  if (_controller.isNaming && _controller.currentText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.mic, color: Colors.blue[700], size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _controller.currentText,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue[900],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Show instruction when listening
                  if (_controller.isNaming)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '🎤 Speak the assistant name clearly, then click "Save Voice Name"',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                if (_controller.hasAssistantName)
                  TextButton(
                    onPressed: () {
                      isDialogActive = false;
                      _controller.removeListener(updateDialog);
                      _controller.cancelVoiceNaming();
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),

                // Save text name button
                if (!_controller.isNaming && _nameController.text.trim().isNotEmpty)
                  ElevatedButton(
                    onPressed: () => _saveTextName(isDialogActive, _controller.removeListener, updateDialog),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save Text Name'),
                  ),

                // Save voice name button
                if (_controller.isNaming && _controller.voiceNameBuffer.isNotEmpty)
                  ElevatedButton(
                    onPressed: () => _saveVoiceName(isDialogActive, _controller.removeListener, updateDialog),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save Voice Name'),
                  ),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      // Cleanup when dialog closes
      isDialogActive = false;
    });
  }

  void _saveTextName(bool isDialogActive, Function removeListener, Function updateDialog) {
    final name = _nameController.text.trim();

    if (name.isEmpty || name.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid name (at least 2 characters)')),
        );
      }
      return;
    }

    _controller.removeListener(updateDialog as void Function());
    _controller.setAssistantName(name);
    if (mounted) Navigator.pop(context);
  }

  void _saveVoiceName(bool isDialogActive, Function removeListener, Function updateDialog) {
    if (_controller.voiceNameBuffer.isEmpty || _controller.voiceNameBuffer.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please say a valid name (at least 2 characters)')),
        );
      }
      return;
    }

    _controller.removeListener(updateDialog as void Function());
    _controller.saveVoiceName();
    if (mounted) Navigator.pop(context);
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 10),
            Text('Reset Assistant'),
          ],
        ),
        content: Text(
          'This will remove the assistant name "${_controller.assistantName}" and clear all conversation history. Are you sure?',
          style: TextStyle(color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _controller.resetAssistant();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Assistant reset successfully')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue[700]),
              const SizedBox(height: 20),
              Text('Loading...', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Voice Assistant', style: TextStyle(color: Colors.black, fontSize: 20)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_controller.hasAssistantName)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              tooltip: 'Rename Assistant',
              onPressed: _showNameDialog,
            ),
          if (_controller.conversationHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Clear History',
              onPressed: _controller.clearHistory,
            ),
          if (_controller.hasAssistantName)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              onSelected: (value) {
                if (value == 'reset') _showResetDialog();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.restart_alt, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Reset Assistant'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          if (_controller.hasAssistantName)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.blue[400]!, Colors.blue[600]!]),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.home, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(_controller.assistantName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _controller.isWakeWordDetected ? Colors.orange[400] : _controller.continuousListening ? Colors.green[400] : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _controller.isWakeWordDetected ? 'READY' : _controller.continuousListening ? 'ACTIVE' : 'IDLE',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          if (_controller.hasAssistantName && _controller.conversationHistory.isEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _controller.isWakeWordDetected ? Colors.green[50] : Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _controller.isWakeWordDetected ? Colors.green[200]! : Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(_controller.isWakeWordDetected ? Icons.check_circle_outline : Icons.lightbulb_outline,
                      color: _controller.isWakeWordDetected ? Colors.green[700] : Colors.amber[700], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _controller.isWakeWordDetected ? 'Ready! Say your command now' : 'Say "${_controller.assistantName}" to activate',
                      style: TextStyle(fontSize: 13, color: _controller.isWakeWordDetected ? Colors.green[900] : Colors.amber[900], fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _controller.conversationHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                          child: Icon(Icons.mic_none, size: 60, color: Colors.blue[400]),
                        ),
                        const SizedBox(height: 20),
                        Text(_controller.hasAssistantName ? 'Tap to start listening' : 'Set assistant name to begin',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                        if (_controller.hasAssistantName) ...[
                          const SizedBox(height: 10),
                          Text('Say "${_controller.assistantName}" to activate', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _controller.conversationHistory.length,
                    itemBuilder: (context, index) {
                      final message = _controller.conversationHistory[index];
                      final isUser = message['type'] == 'user';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            if (!isUser) ...[
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.blue[100],
                                child: Icon(Icons.home, size: 20, color: Colors.blue[700]),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isUser ? Colors.blue[600] : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
                                ),
                                child: Text(message['text'] ?? '', style: TextStyle(fontSize: 15, color: isUser ? Colors.white : Colors.black87, height: 1.4)),
                              ),
                            ),
                            if (isUser) ...[
                              const SizedBox(width: 12),
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.grey[300],
                                child: Icon(Icons.person, size: 20, color: Colors.grey[700]),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (_controller.currentText.isNotEmpty && !_controller.isNaming)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border(top: BorderSide(color: Colors.blue[100]!)),
              ),
              child: Row(
                children: [
                  Icon(Icons.graphic_eq, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_controller.currentText, style: TextStyle(fontSize: 14, color: Colors.blue[900], fontStyle: FontStyle.italic))),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: Column(
              children: [
                Text(
                  _controller.continuousListening
                      ? (_controller.isWakeWordDetected
                          ? 'Ready for command...'
                          : _controller.isSpeaking
                              ? 'Speaking...'
                              : 'Listening for "${_controller.assistantName}"...')
                      : 'Tap to start',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    if (_controller.continuousListening) {
                      _controller.stopListening();
                    } else {
                      if (_controller.hasAssistantName) {
                        _controller.startContinuousListening();
                      } else {
                        _showNameDialog();
                      }
                    }
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _controller.continuousListening ? [Colors.red[400]!, Colors.red[600]!] : [Colors.blue[400]!, Colors.blue[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_controller.continuousListening ? Colors.red : Colors.blue).withOpacity(0.4),
                          blurRadius: _controller.continuousListening ? 20 : 15,
                          spreadRadius: _controller.continuousListening ? 5 : 2,
                        ),
                      ],
                    ),
                    child: Icon(_controller.continuousListening ? Icons.stop : Icons.mic, size: 36, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}