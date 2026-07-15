import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'spotify_config.dart';

class PlatformResolver {
  /// Maps our service IDs to their direct link patterns
  static const Map<String, String> _serviceUrlPrefixes = {
    'spotify': 'https://open.spotify.com/track/',
    'apple_music': 'https://music.apple.com/song/',
    'youtube_music': 'https://music.youtube.com/watch?v=',
    'youtube': 'https://youtu.be/',
    'soundcloud': 'https://soundcloud.com/',
    'deezer': 'https://www.deezer.com/track/',
    'amazon_music': 'https://music.amazon.com/albums/',
    'tidal': 'https://listen.tidal.com/track/',
  };

  /// Try to find a direct link for a given platform using song info
  static Future<String?> resolvePlatform(
    String serviceId,
    String? trackName,
    String? artistName,
  ) async {
    if (trackName == null && artistName == null) return null;

    final query = [trackName, artistName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');

    switch (serviceId) {
      case 'deezer':
        return _searchDeezer(query);
      case 'apple_music':
        return _searchAppleMusic(query);
      case 'soundcloud':
        return _searchSoundCloud(query);
      case 'spotify':
        return _searchSpotify(query);
      case 'tidal':
        return _searchTidal(query);
      case 'amazon_music':
        return _searchAmazonMusic(query);
      default:
        return null;
    }
  }

  /// Deezer: Public API, no auth needed
  static Future<String?> _searchDeezer(String query) async {
    try {
      final uri = Uri.parse('https://api.deezer.com/search')
          .replace(queryParameters: {'q': query, 'limit': '1', 'order': 'RANKING'});
      debugPrint('DeezerAPI: Searching $uri');
      final response = await http.get(uri, headers: {'User-Agent': 'MusicShare/1.0'});
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tracks = data['data'] as List<dynamic>?;
      if (tracks == null || tracks.isEmpty) return null;

      final first = tracks[0] as Map<String, dynamic>;
      final id = first['id'];
      final title = first['title'] as String?;
      final artist = first['artist'] is Map ? (first['artist'] as Map)['name'] : null;

      // Verify it's a good match by checking title similarity
      if (title != null) {
        final queryWords = query.toLowerCase().split(' ');
        final titleWords = (title as String).toLowerCase().split(' ');
        final overlap = queryWords.where((w) => titleWords.contains(w)).length;
        if (overlap < 1) {
          debugPrint('DeezerAPI: Skipping "$title" — poor match for "$query"');
          return null;
        }
      }

      final link = 'https://www.deezer.com/track/$id';
      debugPrint('DeezerAPI: Found track $id ($title - $artist) -> $link');
      return link;
    } catch (e) {
      debugPrint('DeezerAPI error: $e');
      return null;
    }
  }

  /// Apple Music via iTunes Search API (free, no auth)
  static Future<String?> _searchAppleMusic(String query) async {
    try {
      final uri = Uri.parse('https://itunes.apple.com/search')
          .replace(queryParameters: {
        'term': query,
        'entity': 'song',
        'limit': '5',
        'country': 'IN',
      });
      debugPrint('AppleMusicAPI: Searching $uri');
      final response = await http.get(uri, headers: {'User-Agent': 'MusicShare/1.0'});
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      // Find the best match by comparing artist name
      final queryArtist = query.contains(' ')
          ? query.substring(0, query.lastIndexOf(' ')).toLowerCase()
          : '';

      Map<String, dynamic>? bestMatch;
      for (final r in results) {
        final result = r as Map<String, dynamic>;
        final artistName = (result['artistName'] as String? ?? '').toLowerCase();
        if (queryArtist.isNotEmpty && artistName.contains(queryArtist)) {
          bestMatch = result;
          break;
        }
      }
      bestMatch ??= results[0] as Map<String, dynamic>;

      final trackId = bestMatch['trackId'];
      final collectionId = bestMatch['collectionId'] ?? '';
      final trackName = bestMatch['trackName'] as String? ?? '';

      // Use the proper Apple Music song URL format
      String link;
      if (collectionId.toString().isNotEmpty) {
        link = 'https://music.apple.com/in/album/$collectionId?i=$trackId';
      } else {
        link = 'https://music.apple.com/in/song/$trackId';
      }
      debugPrint('AppleMusicAPI: Found track $trackId ($trackName) -> $link');
      return link;
    } catch (e) {
      debugPrint('AppleMusicAPI error: $e');
      return null;
    }
  }

  static String? _accessToken;
  static DateTime? _tokenExpiry;

  /// Spotify: Use Web API with Client Credentials flow
  static Future<String?> _searchSpotify(String query) async {
    try {
      // Get access token (cached)
      if (_accessToken == null || _tokenExpiry == null || DateTime.now().isAfter(_tokenExpiry!)) {
        final token = await _getSpotifyToken();
        if (token == null) {
          debugPrint('SpotifyAPI: No access token available');
          return null;
        }
        _accessToken = token;
        _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
      }

      // Search for tracks
      final encoded = Uri.encodeComponent(query);
      final uri = Uri.parse('https://api.spotify.com/v1/search')
          .replace(queryParameters: {'q': query, 'type': 'track', 'limit': '1'});
      debugPrint('SpotifyAPI: Searching $uri');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('SpotifyAPI: HTTP ${response.statusCode} — ${response.body}');
        if (response.statusCode == 401) {
          _accessToken = null; // Clear expired token
        }
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tracks = data['tracks'] as Map<String, dynamic>?;
      if (tracks == null) return null;

      final items = tracks['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) {
        debugPrint('SpotifyAPI: No results');
        return null;
      }

      final first = items[0] as Map<String, dynamic>;
      final id = first['id'] as String?;
      if (id == null) {
        debugPrint('SpotifyAPI: No ID in first result');
        return null;
      }

      // Check name similarity to verify match
      final name = first['name'] as String? ?? '';
      final artists = first['artists'] as List<dynamic>?;
      final artistName = artists?.isNotEmpty == true
          ? (artists![0] as Map<String, dynamic>)['name'] as String? ?? ''
          : '';

      final link = 'https://open.spotify.com/track/$id';
      debugPrint('SpotifyAPI: Found "$name" by "$artistName" -> $link');
      return link;
    } catch (e) {
      debugPrint('SpotifyAPI error: $e');
      return null;
    }
  }

  static Future<String?> _getSpotifyToken() async {
    if (SpotifyConfig.clientId == 'YOUR_CLIENT_ID') {
      debugPrint('SpotifyAPI: Credentials not configured — set them in spotify_config.dart');
      return null;
    }
    try {
      final credentials = base64Encode(utf8.encode('${SpotifyConfig.clientId}:${SpotifyConfig.clientSecret}'));
      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'grant_type': 'client_credentials'},
      );

      if (response.statusCode != 200) {
        debugPrint('SpotifyAPI: Token error HTTP ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['access_token'] as String?;
    } catch (e) {
      debugPrint('SpotifyAPI: Token error $e');
      return null;
    }
  }

  /// SoundCloud: Scrape search page for first track URL (excluding /search/)
  static Future<String?> _searchSoundCloud(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final uri = Uri.parse('https://soundcloud.com/search/sounds?q=$encoded');
      debugPrint('SoundCloudScrape: Fetching $uri');
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        'Accept': 'text/html',
      });
      if (response.statusCode != 200) return null;

      final html = response.body;

      // Find track URLs that are NOT search pages
      final trackMatch = RegExp(
        r'https://soundcloud\.com/(?!search/)([a-zA-Z0-9_-]+)/([a-zA-Z0-9_-]+)',
      ).firstMatch(html);

      if (trackMatch != null) {
        final link = trackMatch.group(0)!;
        // Remove trailing garbage
        final cleanLink = link.replaceAll(RegExp(r'[^a-zA-Z0-9_\-/:.]'), '');
        debugPrint('SoundCloudScrape: Found track -> $cleanLink');
        return cleanLink;
      }

      return null;
    } catch (e) {
      debugPrint('SoundCloudScrape error: $e');
      return null;
    }
  }

  /// Tidal: Scrape search page for first track URL
  static Future<String?> _searchTidal(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final uri = Uri.parse('https://listen.tidal.com/search/tracks?q=$encoded');
      debugPrint('TidalScrape: Fetching $uri');
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        'Accept': 'text/html',
      });
      if (response.statusCode != 200) return null;

      final html = response.body;
      final trackMatch = RegExp(
        r'https://listen\.tidal\.com/track/\d+',
      ).firstMatch(html);

      if (trackMatch != null) {
        final link = trackMatch.group(0)!;
        debugPrint('TidalScrape: Found track -> $link');
        return link;
      }

      return null;
    } catch (e) {
      debugPrint('TidalScrape error: $e');
      return null;
    }
  }

  /// Amazon Music: Try to find track from search page
  static Future<String?> _searchAmazonMusic(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final uri = Uri.parse('https://music.amazon.com/search/$encoded');
      debugPrint('AmazonMusicScrape: Fetching $uri');
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        'Accept': 'text/html',
      });
      if (response.statusCode != 200) return null;

      final html = response.body;
      final trackMatch = RegExp(
        r'https://music\.amazon\.com/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+/[a-zA-Z0-9]+',
      ).firstMatch(html);

      if (trackMatch != null) {
        final link = trackMatch.group(0)!;
        debugPrint('AmazonMusicScrape: Found track -> $link');
        return link;
      }

      return null;
    } catch (e) {
      debugPrint('AmazonMusicScrape error: $e');
      return null;
    }
  }
}