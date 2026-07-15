import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pulse_share/features/share_handler/services/share_intent_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PulseShare'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/logo.jpg',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Share Music Instantly',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Share music from any app, and let receivers choose their preferred service',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 48),
            OutlinedButton.icon(
              onPressed: () => _showHowItWorks(context),
              icon: const Icon(Icons.school),
              label: const Text('How It Works'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(200, 48),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _showManualInput(context),
              icon: const Icon(Icons.edit),
              label: const Text('Manual Input'),
              style: TextButton.styleFrom(
                minimumSize: const Size(200, 48),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualInput(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Music Link or Text'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Paste URL or song info here',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(context);
                context.read<ShareIntentService>().handleSharedText([text]);
              }
            },
            child: const Text('Process'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PulseShare'),
        content: const Text(
            'This app helps you share music links in a smart way.\n\n1. Click share from any music app\n2. Select PulseShare\n3. Receivers get links for all popular services\n4. They listen on their favorite platform',
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showHowItWorks(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How It Works'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('1️⃣ Share from any music app'),
              const SizedBox(height: 8),
              const Text('2️⃣ Select "PulseShare" from share menu'),
              const SizedBox(height: 8),
              const Text('3️⃣ App analyzes and extracts song info'),
              const SizedBox(height: 8),
              const Text('4️⃣ You see links for all services'),
              const SizedBox(height: 8),
              const Text('5️⃣ Send to your friend'),
              const SizedBox(height: 8),
              const Text('6️⃣ They tap their preferred service link'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}