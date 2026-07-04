import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:music_share/core/constants/music_services.dart';
import 'package:music_share/features/share_handler/services/share_intent_service.dart';
import 'package:music_share/features/share_handler/data/models/music_link.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Share'),
      ),
      body: Consumer<ShareIntentService>(
        builder: (context, service, child) {
          final link = service.currentLink;
          if (link == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text('No link available'),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Share Again'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSongInfoCard(context, link),
              const SizedBox(height: 24),
              const Text(
                'Available on',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...link.availableLinks.map((link) => _buildServiceLinkTile(
                    context,
                    link,
                    link.service.id == MusicServices.spotify.id ||
                        link.service.id == MusicServices.appleMusic.id ||
                        link.service.id == MusicServices.youtubeMusic.id,
                  )),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => service.shareAllLinks(),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('Share All Links'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSongInfoCard(BuildContext context, MusicLink link) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.music_note,
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.displayTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (link.sourceService != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Detected: ${link.sourceService!.name}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceLinkTile(
    BuildContext context,
    ServiceLink link,
    bool isPopular,
  ) {
    final color = isPopular ? link.service.brandColor : Colors.grey;
    final iconData = _getIconDataForService(link.service.id);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withAlpha(32),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          iconData,
          color: color,
          size: 24,
        ),
      ),
      title: Text(link.service.name),
      subtitle: Text(link.url),
      trailing: OutlinedButton.icon(
        onPressed: () => context.read<ShareIntentService>().openLinkInService(link.service),
        icon: const Icon(Icons.open_in_new),
        label: const Text('Open'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 32),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
      onTap: () => context.read<ShareIntentService>().openLinkInService(link.service),
    );
  }

  IconData _getIconDataForService(String id) {
    return Icons.music_note;
  }
}