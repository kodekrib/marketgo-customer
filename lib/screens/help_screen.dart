import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app.dart';
import '../models/faq.dart';
import '../services/faq_service.dart';

/// Full-screen Help & Support for the customer app: FAQs from the backend
/// plus contact options. Replaces the old placeholder InfoScreen.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final FaqService _faqs = FaqService();
  List<FaqEntry>? _entries;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await _faqs.byTarget('customer');
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _entries = customerDemoFaqs();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      backgroundColor: CustomerApp.surfaceMuted,
      appBar: AppBar(
        backgroundColor: CustomerApp.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        title: const Text('Help & support'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [CustomerApp.brandGreenDark, CustomerApp.brandGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.help_outline_rounded, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'We\'re here to help with orders, deliveries and payments.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _ContactCard(
                  icon: Icons.phone_outlined,
                  label: 'Call us',
                  launchUri: Uri(scheme: 'tel', path: '1800MARKETGO'),
                  labelText: 'Call us',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ContactCard(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  launchUri: Uri(scheme: 'mailto', path: 'support@marketgo.io'),
                  labelText: 'Email',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ContactCard(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chat',
                  launchUri: Uri(scheme: 'https', host: 'marketgo.io', path: 'live-chat'),
                  labelText: 'Chat',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Frequently asked questions',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (entries != null)
            ...entries.map(
              (e) => _FaqTile(question: e.question, answer: e.answer),
            ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.label,
    required this.launchUri,
    required this.labelText,
  });

  final IconData icon;
  final String label;
  final Uri launchUri;
  final String labelText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _launch(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: CustomerApp.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: CustomerApp.brandGreenDark),
            const SizedBox(height: 8),
            Text(labelText,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Future<void> _launch() async {
    await launchUrl(launchUri, mode: LaunchMode.externalApplication);
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: CustomerApp.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        shape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Text(question,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14)),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(answer,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}