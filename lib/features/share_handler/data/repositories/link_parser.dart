import 'package:flutter/foundation.dart';
import 'package:pulse_share/core/constants/music_services.dart';
import '../models/music_link.dart';

class LinkParser {
  static final List<_ServiceConfig> _configs = [
    _ServiceConfig(
      service: MusicServices.spotify,
      idPatterns: [
        RegExp(r'open\.spotify\.com/track/([a-zA-Z0-9]+)'),
        RegExp(r'spotify:track:([a-zA-Z0-9]+)'),
      ],
    ),
    _ServiceConfig(
      service: MusicServices.appleMusic,
      idPatterns: [
        RegExp(r'music\.apple\.com/[\w-]+/song/(\d+)'),
        RegExp(r'music\.apple\.com/[\w-]+/album/[\w-]+/(\d+)'),
      ],
    ),
    _ServiceConfig(
      service: MusicServices.youtubeMusic,
      idPatterns: [
        RegExp(r'music\.youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})'),
        RegExp(r'music\.youtube\.com/playlist\?list=([a-zA-Z0-9_-]+)'),
      ],
    ),
    _ServiceConfig(
      service: MusicServices.youtube,
      idPatterns: [
        RegExp(r'(?:youtube\.com/watch\?v=|youtu\.be/)([a-zA-Z0-9_-]{11})'),
        RegExp(r'youtube\.com/playlist\?list=([a-zA-Z0-9_-]+)'),
      ],
    ),
    _ServiceConfig(
      service: MusicServices.soundCloud,
      idPatterns: [
        RegExp(r'soundcloud\.com/[\w-]+/[\w-]+'),
        RegExp(r'on\.soundcloud\.com/[\w-]+/[\w-]+'),
      ],
    ),
    _ServiceConfig(
      service: MusicServices.deezer,
      idPatterns: [
        RegExp(r'deezer\.com/track/(\d+)'),
        RegExp(r'deezer\.com/[\w-]+/track/(\d+)'),
      ],
    ),
    _ServiceConfig(
      service: MusicServices.amazonMusic,
      idPatterns: [
        RegExp(r'music\.amazon\.com/[\w-]+/[\w-]+/(\w+)'),
        RegExp(r'amazon\.com/[\w-]+/dp/(\w+)'),
      ],
    ),
    _ServiceConfig(
      service: MusicServices.tidal,
      idPatterns: [
        RegExp(r'tidal\.com/track/(\d+)'),
        RegExp(r'tidal\.com/browse/track/(\d+)'),
      ],
    ),
  ];

  static MusicLink parse(String url, {String? trackName, String? artistName}) {
    debugPrint('LinkParser.parse: URL=$url, trackName=$trackName, artistName=$artistName');

    String? extractedId;
    MusicService? detectedService;
    for (final config in _configs) {
      for (final pattern in config.idPatterns) {
        final match = pattern.firstMatch(url);
        if (match != null) {
          extractedId = match.group(1);
          detectedService = config.service;
          debugPrint('LinkParser: Detected service=${detectedService.name}, ID=$extractedId');
          break;
        }
      }
      if (detectedService != null) break;
    }

    if (detectedService == null) {
      debugPrint('LinkParser: No service detected for URL: $url');
    }

    // If no service detected, try to extract title from URL
    if (trackName == null && detectedService == null) {
      trackName = _extractTitleFromUrl(url);
      debugPrint('LinkParser: Extracted title from URL: $trackName');
    }

    final availableLinks = _generateAvailableLinks(
      originalUrl: url,
      sourceService: detectedService,
      trackId: extractedId,
      trackName: trackName,
      artistName: artistName,
    );

    debugPrint('LinkParser: Generated ${availableLinks.length} available links');

    return MusicLink(
      originalUrl: url,
      sourceService: detectedService,
      trackId: extractedId,
      trackName: trackName,
      artistName: artistName,
      availableLinks: availableLinks,
    );
  }

  static bool isGenericTitleOrId(String title) {
    final clean = title.trim().toLowerCase();
    
    // Check common generic words
    final genericWords = {
      'music', 'track', 'song', 'album', 'watch', 'browse', 'search', 'video', 'audio',
      'spotify', 'apple music', 'youtube', 'youtube music', 'soundcloud', 'deezer', 'tidal', 'amazon music', 'web player'
    };
    if (genericWords.contains(clean)) return true;

    // Check if it's a typical base62 ID or hash (no spaces, length >= 10, alphanumeric)
    if (!clean.contains(' ') && clean.length >= 10 && RegExp(r'^[a-z0-9]+$', caseSensitive: false).hasMatch(clean)) {
      return true;
    }

    return false;
  }

  static List<ServiceLink> _generateAvailableLinks({
    required String originalUrl,
    required MusicService? sourceService,
    required String? trackId,
    required String? trackName,
    required String? artistName,
  }) {
    final availableLinks = <ServiceLink>[];

    // Build query for search links
    String? searchQuery;
    if (trackName != null && artistName != null) {
      searchQuery = '$trackName $artistName';
    } else if (trackName != null) {
      searchQuery = trackName;
    } else if (originalUrl.isNotEmpty) {
      // Only extract title from URL if the service stores the title in the URL path
      final canExtract = sourceService == null ||
          sourceService.id == 'soundcloud' ||
          (sourceService.id == 'apple_music' && originalUrl.contains('/album/'));
      if (canExtract) {
        final extracted = _extractTitleFromUrl(originalUrl);
        if (extracted != null && !isGenericTitleOrId(extracted)) {
          searchQuery = extracted;
        }
      }
    }

    final encodedQuery = searchQuery != null && searchQuery.isNotEmpty ? Uri.encodeComponent(searchQuery) : null;

    // 1. Spotify
    if (sourceService?.id == 'spotify' && trackId != null) {
      availableLinks.add(ServiceLink(service: MusicServices.spotify, url: 'https://open.spotify.com/track/$trackId'));
    } else if (encodedQuery != null) {
      availableLinks.add(ServiceLink(service: MusicServices.spotify, url: 'https://open.spotify.com/search/$encodedQuery'));
    }

    // 2. Apple Music
    if (sourceService?.id == 'apple_music' && trackId != null) {
      availableLinks.add(ServiceLink(service: MusicServices.appleMusic, url: 'https://music.apple.com/song/$trackId'));
    } else if (encodedQuery != null) {
      availableLinks.add(ServiceLink(service: MusicServices.appleMusic, url: 'https://music.apple.com/search?term=$encodedQuery'));
    }

    // 3. YouTube Music
    if ((sourceService?.id == 'youtube_music' || sourceService?.id == 'youtube') && trackId != null) {
      availableLinks.add(ServiceLink(service: MusicServices.youtubeMusic, url: 'https://music.youtube.com/watch?v=$trackId'));
    } else if (encodedQuery != null) {
      availableLinks.add(ServiceLink(service: MusicServices.youtubeMusic, url: 'https://music.youtube.com/search?q=$encodedQuery'));
    }

    // 4. YouTube
    if ((sourceService?.id == 'youtube_music' || sourceService?.id == 'youtube') && trackId != null) {
      availableLinks.add(ServiceLink(service: MusicServices.youtube, url: 'https://youtu.be/$trackId'));
    } else if (encodedQuery != null) {
      availableLinks.add(ServiceLink(service: MusicServices.youtube, url: 'https://www.youtube.com/results?search_query=$encodedQuery'));
    }

    // 5. SoundCloud
    if (sourceService?.id == 'soundcloud') {
      availableLinks.add(ServiceLink(service: MusicServices.soundCloud, url: originalUrl));
    } else if (encodedQuery != null) {
      availableLinks.add(ServiceLink(service: MusicServices.soundCloud, url: 'https://soundcloud.com/search?q=$encodedQuery'));
    }

    // 6. Deezer
    if (sourceService?.id == 'deezer' && trackId != null) {
      availableLinks.add(ServiceLink(service: MusicServices.deezer, url: 'https://www.deezer.com/track/$trackId'));
    } else if (encodedQuery != null) {
      availableLinks.add(ServiceLink(service: MusicServices.deezer, url: 'https://www.deezer.com/search/$encodedQuery'));
    }

    // 7. Amazon Music
    if (sourceService?.id == 'amazon_music' && trackId != null) {
      availableLinks.add(ServiceLink(service: MusicServices.amazonMusic, url: 'https://music.amazon.com/search/$encodedQuery'));
    } else if (encodedQuery != null) {
      availableLinks.add(ServiceLink(service: MusicServices.amazonMusic, url: 'https://music.amazon.com/search/$encodedQuery'));
    }

    // 8. Tidal
    if (sourceService?.id == 'tidal' && trackId != null) {
      availableLinks.add(ServiceLink(service: MusicServices.tidal, url: 'https://listen.tidal.com/track/$trackId'));
    } else if (encodedQuery != null) {
      availableLinks.add(ServiceLink(service: MusicServices.tidal, url: 'https://listen.tidal.com/search?q=$encodedQuery'));
    }

    return availableLinks;
  }

  static String? _extractTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments
          .where((s) => s.isNotEmpty && !RegExp(r'^\d+$').hasMatch(s))
          .toList();
      if (pathSegments.isNotEmpty) {
        final title = pathSegments.last
            .replaceAll('-', ' ')
            .replaceAll('_', ' ')
            .replaceAll(RegExp(r'\.[^.]+$'), '');
        return title.split(' ').map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        }).join(' ');
      }
    } catch (_) {}
    return null;
  }
}

class _ServiceConfig {
  final MusicService service;
  final List<RegExp> idPatterns;

  const _ServiceConfig({
    required this.service,
    required this.idPatterns,
  });
}