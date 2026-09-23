/// A single FAQ entry served by `GET /api/v1/faqs/:target`.
class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.question,
    required this.answer,
  });

  final int id;
  final String question;
  final String answer;

  factory FaqEntry.fromJson(Map<String, dynamic> json) {
    return FaqEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
    );
  }
}

/// Built-in help content shown for the customer app when the backend isn't
/// reachable (demo mode).
List<FaqEntry> customerDemoFaqs() {
  return const [
    FaqEntry(
      id: 1,
      question: 'How do I place an order?',
      answer:
          'Browse stores on the Home tab, tap a product to add it to your cart, '
          'then open your cart and check out. Enter your delivery address and '
          'phone number, pay, and a rider will be assigned to your order.',
    ),
    FaqEntry(
      id: 2,
      question: 'How can I track my order?',
      answer:
          'Once a rider has accepted your order and is sharing their location, '
          'open the order from the Orders tab and tap "Track live" to follow '
          'them on the map in real time.',
    ),
    FaqEntry(
      id: 3,
      question: 'How do I pay for my order?',
      answer:
          'At checkout you complete payment securely through the payment '
          'gateway. Your saved payment methods on this device can be reused '
          'for faster checkout.',
    ),
    FaqEntry(
      id: 4,
      question: 'Can I cancel an order?',
      answer:
          'You can cancel an order while it is still pending. Once a rider has '
          'been assigned, contact support for help with your cancellation.',
    ),
    FaqEntry(
      id: 5,
      question: 'How do refunds work?',
      answer:
          'If an order is cancelled before a rider is assigned, your payment is '
          'typically reversed automatically. For other cases, contact support '
          'and we will help resolve it.',
    ),
    FaqEntry(
      id: 6,
      question: 'What if my order is wrong or damaged?',
      answer:
          'Contact support within 24 hours of delivery with your order number '
          'and a short description — we will arrange a fix or refund.',
    ),
  ];
}