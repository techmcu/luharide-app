import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../core/config/env_config.dart';

/// Socket.IO client — matches Node `socket.io` server (same host as [EnvConfig.socketUrl], no `/api`).
/// Events: `trip-updated`, `notification:new`, `driver-location`.
class RealtimeSocketService {
  RealtimeSocketService._();
  static final RealtimeSocketService instance = RealtimeSocketService._();

  socket_io.Socket? _socket;
  final Set<String> _pendingTripJoins = {};
  Timer? _reconnectBackoffTimer;
  bool _isReconnectingManually = false;

  final _tripUpdated = StreamController<Map<String, dynamic>>.broadcast();
  final _notifications = StreamController<Map<String, dynamic>>.broadcast();
  final _driverLocation = StreamController<Map<String, dynamic>>.broadcast();

  /// Booking / seat changes for a trip (payload includes `tripId`).
  Stream<Map<String, dynamic>> get tripUpdatedStream => _tripUpdated.stream;

  /// New in-app notification row from server.
  Stream<Map<String, dynamic>> get notificationStream => _notifications.stream;

  /// Live driver GPS for passengers in the same trip room.
  Stream<Map<String, dynamic>> get driverLocationStream => _driverLocation.stream;

  bool get isConnected => _socket != null && _socket!.disconnected == false;

  Future<void> connect() async {
    _reconnectBackoffTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) {
      await disconnect();
      return;
    }

    await disconnect();

    final base = EnvConfig.socketUrl.replaceAll(RegExp(r'/+$'), '');
    _socket = socket_io.io(
      base,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth(<String, dynamic>{'token': token})
          .enableReconnection()
          .setReconnectionAttempts(12)
          .setReconnectionDelay(1500)
          .setTimeout(20000)
          .build(),
    );

    _socket!.on('connect', (_) {
      _isReconnectingManually = false;
      if (kDebugMode) {
        // ignore: avoid_print
        print('🔌 Socket.IO connected');
      }
      _flushTripJoins();
    });

    _socket!.on('disconnect', (_) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('🔌 Socket.IO disconnected');
      }
    });

    _socket!.on('connect_error', (dynamic e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('🔌 Socket.IO connect_error: $e');
      }
      _scheduleManualReconnect();
    });

    _socket!.on('reconnect_failed', (_) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('🔌 Socket.IO reconnect_failed');
      }
      _scheduleManualReconnect();
    });

    _socket!.on('trip-updated', (dynamic data) {
      if (data is Map) {
        _tripUpdated.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('notification:new', (dynamic data) {
      if (data is Map && data['notification'] != null) {
        final n = data['notification'];
        if (n is Map) {
          _notifications.add(Map<String, dynamic>.from(n));
        }
      }
    });

    _socket!.on('driver-location', (dynamic data) {
      if (data is Map) {
        _driverLocation.add(Map<String, dynamic>.from(data));
      }
    });

  }

  void _scheduleManualReconnect() {
    if (_isReconnectingManually) return;
    _isReconnectingManually = true;
    _reconnectBackoffTimer?.cancel();
    _reconnectBackoffTimer = Timer(const Duration(seconds: 4), () async {
      try {
        await connect();
      } catch (_) {
      } finally {
        _isReconnectingManually = false;
      }
    });
  }

  void _flushTripJoins() {
    final s = _socket;
    if (s == null) return;
    for (final id in _pendingTripJoins) {
      s.emit('join-trip', id);
    }
  }

  /// Subscribe to realtime updates for this trip (call from trip detail / seat selection).
  void joinTrip(String tripId) {
    if (tripId.isEmpty) return;
    _pendingTripJoins.add(tripId);
    if (isConnected) {
      _socket?.emit('join-trip', tripId);
    }
  }

  void leaveTrip(String tripId) {
    if (tripId.isEmpty) return;
    _pendingTripJoins.remove(tripId);
    _socket?.emit('leave-trip', tripId);
  }

  /// Driver: push GPS to passengers in the trip room.
  void sendDriverLocation({
    required String tripId,
    required double lat,
    required double lng,
    double? speed,
  }) {
    _socket?.emit('location-update', {
      'tripId': tripId,
      'lat': lat,
      'lng': lng,
      if (speed != null) 'speed': speed,
    });
  }

  Future<void> disconnect() async {
    _reconnectBackoffTimer?.cancel();
    _reconnectBackoffTimer = null;
    _isReconnectingManually = false;
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
  }
}
