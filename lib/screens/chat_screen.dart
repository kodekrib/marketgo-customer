import 'dart:async';

import 'package:flutter/material.dart';
import '../app.dart';
import '../models/marketplace.dart';
import '../services/api_client.dart';
import '../services/chat_service.dart';
import '../services/websocket_service.dart';

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.fromMe,
    required this.time,
  });

  final String text;
  final bool fromMe;
  final String time;
}

/// Customer chat UI for messaging the rider while a delivery is live.
///
/// When [deliveryId], [token] and [ws] are provided the screen runs against
/// the realtime backend: history is loaded from /api/v1/chat/:deliveryId,
/// sends go over the same endpoint, and inbound messages arrive live as
/// `chat.message` WebSocket events. Without those the screen keeps its
/// local mock behaviour (used by card previews that have no delivery yet).
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.order,
    this.contactName = 'Rider',
    this.contactSubtitle = 'MarketGO Rider',
    this.contactInitials = 'DR',
    this.send,
    this.deliveryId,
    this.token,
    this.currentUserId,
    this.ws,
    this.api,
  });

  /// The live order being chatted about (shown in a header banner).
  final Order? order;
  final String contactName;
  final String contactSubtitle;
  final String contactInitials;

  /// Overridable send hook; defaults to a local mock reply.
  final Future<String> Function(String message)? send;

  /// The delivery whose thread this screen shows. Null keeps mock mode.
  final int? deliveryId;
  final String? token;

  /// The signed-in customer's numeric id, used to align history bubbles.
  final int? currentUserId;

  /// Shared WebSocket connection to receive inbound messages in real time.
  final CustomerWebSocket? ws;
  final ApiClient? api;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _typing = false;
  Timer? _replyTimer;
  ChatService? _service;
  StreamSubscription<WsEvent>? _chatSub;

  bool get _live =>
      widget.deliveryId != null &&
      widget.token != null &&
      widget.token!.isNotEmpty;

  String get _now {
    final t = TimeOfDay.now();
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    var h = local.hour % 12;
    if (h == 0) h = 12;
    final m = local.minute.toString().padLeft(2, '0');
    final ap = local.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }

  @override
  void initState() {
    super.initState();
    if (_live) {
      _service = ChatService(api: widget.api);
      _watchInbound();
      _loadHistory();
    } else {
      _messages.add(_ChatMessage(
        text: 'Hi! I\'m on my way with your order. Any questions, just ask.',
        fromMe: false,
        time: _now,
      ));
    }
  }

  void _watchInbound() {
    final ws = widget.ws;
    if (ws == null) return;
    _chatSub = ws.chatMessage.listen((event) {
      if (!mounted) return;
      final payload = event.payload;
      if (payload is! Map<String, dynamic>) return;
      final deliveryId = (payload['delivery_id'] as num?)?.toInt();
      if (deliveryId == null || deliveryId != widget.deliveryId) return;
      setState(() {
        _messages.add(_ChatMessage(
          text: payload['body'] as String? ?? '',
          fromMe: false,
          time: _formatTime(
            DateTime.tryParse(payload['created_at'] as String? ?? '') ??
                DateTime.now(),
          ),
        ));
      });
      _scrollToBottom();
    });
  }

  Future<void> _loadHistory() async {
    final token = widget.token!;
    final deliveryId = widget.deliveryId!;
    try {
      final (_, history) =
          await _service!.conversation(token, deliveryId);
      if (!mounted) return;
      setState(() {
        for (final m in history) {
          _messages.add(_ChatMessage(
            text: m.body,
            fromMe: m.senderId == widget.currentUserId,
            time: _formatTime(m.createdAt),
          ));
        }
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 409) return;
      _toast('Couldn\'t load messages: ${e.message}');
    } catch (_) {
      _toast('Couldn\'t load messages.');
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() {
      _messages.add(_ChatMessage(text: text, fromMe: true, time: _now));
    });
    _scrollToBottom();

    if (_live) {
      try {
        await _service!.send(widget.token!, widget.deliveryId!, text);
      } on ApiException catch (e) {
        // Restore the draft on failure so the customer doesn't lose it.
        _input.text = text;
        _toast('Message failed: ${e.message}');
      } catch (_) {
        _input.text = text;
        _toast('Message failed. Try again.');
      }
      return;
    }

    _typing = true;
    _replyTimer?.cancel();
    _replyTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      const reply =
          'On my way! I\'ll update you when I arrive.';
      setState(() {
        _messages.add(_ChatMessage(
          text: reply,
          fromMe: false,
          time: _now,
        ));
        _typing = false;
      });
      _scrollToBottom();
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _replyTimer?.cancel();
    _chatSub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Scaffold(
      backgroundColor: CustomerApp.surfaceMuted,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        automaticallyImplyLeading: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.contactName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: CustomerApp.ink,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.circle,
                    size: 8, color: Color(0xFF22C55E)),
                const SizedBox(width: 5),
                Text(
                  widget.contactSubtitle,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5B616A)),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (order != null) _OrderBanner(order: order),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              itemCount: _messages.length + (_typing ? 1 : 0),
              itemBuilder: (context, index) {
                if (_typing && index == _messages.length) {
                  return const _TypingBubble();
                }
                return _Bubble(message: _messages[index]);
              },
            ),
          ),
          _Composer(
            controller: _input,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

/// Compact banner contextualising the conversation with the live order.
class _OrderBanner extends StatelessWidget {
  const _OrderBanner({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CustomerApp.brandGreenLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.delivery_dining_rounded,
              color: CustomerApp.brandGreenDark, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.vendor} · ${order.id}',
                  style: TextStyle(
                    color: CustomerApp.brandGreenDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  order.meta,
                  style: TextStyle(
                    color: CustomerApp.brandGreenDark,
                    fontSize: 12,
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: message.fromMe
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        decoration: BoxDecoration(
          color: message.fromMe ? CustomerApp.brandGreen : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.fromMe ? 18 : 4),
            bottomRight: Radius.circular(message.fromMe ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.fromMe ? Colors.white : CustomerApp.ink,
                fontSize: 14.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message.time,
              style: TextStyle(
                color: message.fromMe
                    ? Colors.white70
                    : theme.textTheme.bodySmall?.color,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _TypingDot(i),
            );
          }),
        ),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  const _TypingDot(this.index);

  final int index;

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Color(0xFF9AA1AA),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.only(left: 16, right: 12, top: 10, bottom: 10),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  filled: true,
                  fillColor: CustomerApp.surfaceMuted,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                onPressed: onSend,
                style: IconButton.styleFrom(
                  backgroundColor: CustomerApp.brandGreen,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send_rounded, size: 20),
                tooltip: 'Send',
              ),
            ),
          ],
        ),
      ),
    );
  }
}