import 'api_client.dart';

/// A single message on a delivery chat thread.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.deliveryId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final int id;
  final int conversationId;
  final int deliveryId;
  final int senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      conversationId: (json['conversation_id'] as num?)?.toInt() ?? 0,
      deliveryId: (json['delivery_id'] as num?)?.toInt() ?? 0,
      senderId: (json['sender_id'] as num?)?.toInt() ?? 0,
      body: json['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      readAt: DateTime.tryParse(json['read_at'] as String? ?? ''),
    );
  }
}

/// A delivery-scoped customer-rider thread.
class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.deliveryId,
    required this.customerId,
    required this.riderId,
    this.lastMessage = '',
  });

  final int id;
  final int deliveryId;
  final int customerId;
  final int riderId;
  final String lastMessage;

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      deliveryId: (json['delivery_id'] as num?)?.toInt() ?? 0,
      customerId: (json['customer_id'] as num?)?.toInt() ?? 0,
      riderId: (json['rider_id'] as num?)?.toInt() ?? 0,
      lastMessage: json['last_message'] as String? ?? '',
    );
  }
}

/// Calls the marketgo-api chat endpoints for the logged-in customer.
///
/// Threads are one per delivery; the server authorizes access to the
/// delivery's customer, its rider, or an admin.
class ChatService {
  ChatService({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  Map<String, String> _auth(String token) =>
      {'Authorization': 'Bearer $token'};

  /// Loads the full history for a delivery thread. Opening a thread also
  /// marks its inbound messages as read.
  Future<(ChatConversation, List<ChatMessage>)> conversation(
    String token,
    int deliveryId,
  ) async {
    final data = await api.get(
      '/api/v1/chat/$deliveryId',
      headers: _auth(token),
    );
    final conversation = ChatConversation.fromJson(
      data['conversation'] is Map<String, dynamic>
          ? data['conversation'] as Map<String, dynamic>
          : <String, dynamic>{},
    );
    final raw = data['messages'];
    final messages = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(ChatMessage.fromJson)
            .toList()
        : <ChatMessage>[];
    return (conversation, messages);
  }

  /// Posts a message to a delivery thread and returns the stored message.
  Future<ChatMessage> send(String token, int deliveryId, String body) async {
    final data = await api.post(
      '/api/v1/chat/$deliveryId',
      headers: _auth(token),
      body: {'body': body},
    );
    final msg = data['message'];
    if (msg is! Map<String, dynamic>) {
      throw const ApiException('Unexpected send response', statusCode: 500);
    }
    return ChatMessage.fromJson(msg);
  }
}