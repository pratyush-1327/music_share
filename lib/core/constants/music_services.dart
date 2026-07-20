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

  static final soundCloud = MusicService(
    id: 'soundcloud',
    name: 'SoundCloud',
    iconName: 'soundcloud',
    brandColor: Color(0xFFFF5500),
    baseUrl: 'https://soundcloud.com',
    urlPattern: RegExp(r'soundcloud\.com/[\w-]+/[\w-]+'),
  );

  static final deezer = MusicService(
    id: 'deezer',
    name: 'Deezer',
    iconName: 'deezer',
    brandColor: Color(0xFF00C7FD),
    baseUrl: 'https://www.deezer.com',
    urlPattern: RegExp(r'deezer\.com/track/(\d+)'),
  );

  static final amazonMusic = MusicService(
    id: 'amazon_music',
    name: 'Amazon Music',
    iconName: 'amazon',
    brandColor: Color(0xFF00A8E1),
    baseUrl: 'https://music.amazon.com',
    urlPattern: RegExp(r'music\.amazon\.com/[\w-]+/[\w-]+/(\w+)'),
  );

  static final tidal = MusicService(
    id: 'tidal',
    name: 'Tidal',
    iconName: 'tidal',
    brandColor: Color(0xFF000000),
    baseUrl: 'https://listen.tidal.com',
    urlPattern: RegExp(r'tidal\.com/track/(\d+)'),
  );

  static List<MusicService> get allServices => [
        spotify,
        appleMusic,
        youtubeMusic,
        youtube,
        amazonMusic,
        tidal,
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
      case 'amazon_music':
        return 'https://music.amazon.com/search?q=$trackId';
      case 'tidal':
        return 'https://listen.tidal.com/track/$trackId';
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

  static String generateSearchLink(MusicService service, String? trackName, String? artistName) {
    final queryParts = [trackName, artistName].where((s) => s != null && s.isNotEmpty).toList();
    if (queryParts.isEmpty) return '';
    final query = Uri.encodeComponent(queryParts.join(' '));
    switch (service.id) {
      case 'spotify':
        return 'https://open.spotify.com/search/$query';
      case 'apple_music':
        return 'https://music.apple.com/search?term=$query';
      case 'youtube_music':
        return 'https://music.youtube.com/search?q=$query';
      case 'youtube':
        return 'https://www.youtube.com/results?search_query=$query';
      case 'amazon_music':
        return 'https://music.amazon.com/search/$query';
      case 'tidal':
        return 'https://listen.tidal.com/search?q=$query';
      default:
        return '';
    }
  }
}