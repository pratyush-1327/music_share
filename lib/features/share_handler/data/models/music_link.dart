import 'package:pulse_share/core/constants/music_services.dart';

class MusicLink {
  final String originalUrl;
  final MusicService? sourceService;
  final String? trackId;
  final String? trackName;
  final String? artistName;
  final String? albumName;
  final List<ServiceLink> availableLinks;

  MusicLink({
    required this.originalUrl,
    this.sourceService,
    this.trackId,
    this.trackName,
    this.artistName,
    this.albumName,
    required this.availableLinks,
  });

  bool get hasMetadata => trackName != null || artistName != null;

  ServiceLink get sourceLink {
    final match = availableLinks.where((l) => l.service.id == sourceService?.id);
    return match.isNotEmpty ? match.first : availableLinks.first;
  }

  String get displayTitle {
    if (trackName != null && artistName != null) {
      return '$trackName - $artistName';
    }
    if (trackName != null) {
      return trackName!;
    }
    return 'Music Link';
  }

  String generateShareMessage() {
    final buffer = StringBuffer();

    buffer.writeln('🎵 $displayTitle');
    buffer.writeln();
    buffer.writeln('Available on:');
    for (final link in availableLinks) {
      buffer.writeln('🔗 ${link.service.name}: ${link.url}');
    }
    buffer.writeln();
    buffer.writeln('Shared via PulseShare');

    return buffer.toString();
  }

  String generateShareSubject() {
    return displayTitle;
  }
}

class ServiceLink {
  final MusicService service;
  final String url;

  const ServiceLink({
    required this.service,
    required this.url,
  });

  bool get isAvailable => url.isNotEmpty;
}