import 'package:flutter/material.dart';

class MusicService {
  final String id;
  final String name;
  final String iconName;
  final Color brandColor;
  final String baseUrl;
  final RegExp urlPattern;

  MusicService({
    required this.id,
    required this.name,
    required this.iconName,
    required this.brandColor,
    required this.baseUrl,
    required this.urlPattern,
  });

  String? extractIdFromUrl(String url) {
    final match = urlPattern.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }
}

class MusicServices {
  static final spotify = MusicService(
    id: 'spotify',
    name: 'Spotify',
    iconName: 'spotify',
    brandColor: Color(0xFF1DB954),
    baseUrl: 'https://open.spotify.com',
    urlPattern: RegExp(r'open\.spotify\.com/track/([a-zA-Z0-9]+)'),
  );

  static final appleMusic = MusicService(
    id: 'apple_music',
    name: 'Apple Music',
    iconName: 'apple',
    brandColor: Color(0xFFFC3C44),
    baseUrl: 'https://music.apple.com',
    urlPattern: RegExp(r'music\.apple\.com/[\w-]+/song/(\d+)'),
  );

  static final youtubeMusic = MusicService(
    id: 'youtube_music',
    name: 'YouTube Music',
    iconName: 'youtube',
    brandColor: Color(0xFFFF0000),
    baseUrl: 'https://music.youtube.com',
    urlPattern: RegExp(r'music\.youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})'),
  );

  static final youtube = MusicService(
    id: 'youtube',
    name: 'YouTube',
    iconName: 'youtube',
    brandColor: Color(0xFFFF0000),
    baseUrl: 'https://www.youtube.com',
    urlPattern: RegExp(r'(?:youtube\.com/watch\?v=|youtu\.be/)([a-zA-Z0-9_-]{11})'),
  );

  static List<MusicService> get allServices => [
        spotify,
        appleMusic,
        youtubeMusic,
        youtube,
      ];

  static String generateLink(MusicService service, String trackId) {
    switch (service.id) {
      case 'spotify':
        return 'https://open.spotify.com/track/$trackId';
      case 'apple_music':
        return 'https://music.apple.com/song/$trackId';
      case 'youtube_music':
        return 'https://music.youtube.com/watch?v=$trackId';
      case 'youtube':
        return 'https://youtu.be/$trackId';
      default:
        return '';
    }
  }

  static MusicService? detectService(String url) {
    for (final service in allServices) {
      if (service.urlPattern.hasMatch(url)) {
        return service;
      }
    }
    return null;
  }
}