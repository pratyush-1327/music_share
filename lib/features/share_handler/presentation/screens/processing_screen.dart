import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/share_intent_service.dart';

class ProcessingScreen extends StatelessWidget {
  const ProcessingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Share'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 64),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
              strokeWidth: 3,
            ),
            const SizedBox(height: 32),
            const Text(
              'Analyzing link...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
                      const SizedBox(height: 16),
                      Consumer<ShareIntentService>(
                        builder: (context, service, child) {
                          return Text(
                            'Extracting song info',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}