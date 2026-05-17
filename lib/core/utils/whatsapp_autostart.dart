import 'dart:io';
import 'package:flutter/foundation.dart';

/// Utility to automatically manage and start the WhatsApp server in development
class WhatsAppAutostart {
  static const int port = 12456;

  /// Starts the WhatsApp server if we are running in debug mode on Windows
  /// and the server is not already active.
  static Future<void> init() async {
    // Platform is not supported on web, so return early
    if (kIsWeb) return;

    // Only auto-start during local development (debug mode) on Windows
    if (!kDebugMode || !Platform.isWindows) return;

    try {
      final isRunning = await _isServerRunning();
      if (isRunning) {
        debugPrint('📱 WhatsApp Server is already running. Skipping autostart.');
        return;
      }

      debugPrint('🚀 WhatsApp Server is not running. Starting it in the background...');
      await _startServer();
    } catch (e) {
      debugPrint('⚠️ Error checking or starting WhatsApp Server: $e');
    }
  }

  /// Checks if the WhatsApp server is running by attempting to connect to its lock port
  static Future<bool> _isServerRunning() async {
    try {
      final socket = await Socket.connect('127.0.0.1', port, timeout: const Duration(milliseconds: 500));
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Starts the WhatsApp server as a detached background process
  static Future<void> _startServer() async {
    try {
      // Find the project directory
      final projectDir = Directory.current;
      var serverDir = Directory('${projectDir.path}/whatsapp-server');

      if (!await serverDir.exists()) {
        // Fallback: search parent directories up to 3 levels
        var parent = projectDir.parent;
        for (var i = 0; i < 3; i++) {
          final testDir = Directory('${parent.path}/whatsapp-server');
          if (await testDir.exists()) {
            serverDir = testDir;
            break;
          }
          parent = parent.parent;
        }
      }

      if (!await serverDir.exists()) {
        debugPrint('❌ WhatsApp server directory not found at relative paths.');
        return;
      }

      // Check if node is installed
      try {
        final result = await Process.run('node', ['--version']);
        if (result.exitCode != 0) {
          debugPrint('❌ Node.js is not available in the system PATH.');
          return;
        }
      } catch (_) {
        debugPrint('❌ Node.js is not installed or not in PATH.');
        return;
      }

      // Start node index.js in detached mode
      final process = await Process.start(
        'node',
        ['index.js'],
        workingDirectory: serverDir.path,
        mode: ProcessStartMode.detached,
      );

      debugPrint('✅ Started WhatsApp Server background process with PID: ${process.pid}');
    } catch (e) {
      debugPrint('❌ Failed to start WhatsApp Server: $e');
    }
  }
}
