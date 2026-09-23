import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';

/// Event received from the backend WebSocket.
class WsEvent {
  const WsEvent({required this.type, this.payload});

  final String type;
  final dynamic payload;

  factory WsEvent.fromJson(Map<String, dynamic> json) {
    return WsEvent(
      type: json['type'] as String? ?? '',
      payload: json['payload'],
    );
  }
}

/// Manages a persistent WebSocket connection for the customer app.
///
/// The connection authenticates via the JWT access token and receives:
/// - `delivery.location_updated` — rider GPS fixes for live tracking
/// - `delivery.status_changed` — delivery lifecycle transitions
/// - `order.status_changed` — order status transitions
/// - `notification.new` — in-app notifications
class CustomerWebSocket {
  CustomerWebSocket({required this.api});

  final ApiClient api;

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _intentionalClose = false;
  String? _token;

  final _events = StreamController<WsEvent>.broadcast();
  Stream<WsEvent> get events => _events.stream;

  /// Convenience streams for specific event types.
  Stream<WsEvent> get riderLocation => events.where((e) => e.type == 'delivery.location_updated');
  Stream<WsEvent> get deliveryStatus => events.where((e) => e.type == 'delivery.status_changed');
  Stream<WsEvent> get orderStatus => events.where((e) => e.type == 'order.status_changed');
  Stream<WsEvent> get notification => events.where((e) => e.type == 'notification.new');

  /// Connects with the given JWT access token. Calling this again disconnects
  /// any existing connection first.
  void connect(String token) {
    disconnect();
    _intentionalClose = false;
    _token = token;
    _doConnect();
  }

  void _doConnect() {
    if (_token == null || _intentionalClose) return;

    final wsUrl = api.baseUrl.replaceFirst('http', 'ws');
    final uri = Uri.parse('$wsUrl/ws?token=$_token');

    try {
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            _events.add(WsEvent.fromJson(json));
          } catch (_) {}
        },
        onError: (_) => _scheduleReconnect(),
        onDone: () {
          if (!_intentionalClose) _scheduleReconnect();
        },
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), _doConnect);
  }

  /// Sends a message to the server (e.g. joining a delivery room).
  void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  /// Joins a room to receive events for a specific delivery.
  void joinDeliveryRoom(int deliveryId) {
    send({'action': 'join', 'room': 'delivery:$deliveryId'});
  }

  /// Leaves a delivery room.
  void leaveDeliveryRoom(int deliveryId) {
    send({'action': 'leave', 'room': 'delivery:$deliveryId'});
  }

  /// Disconnects and stops reconnecting.
  void disconnect() {
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _events.close();
  }
}
