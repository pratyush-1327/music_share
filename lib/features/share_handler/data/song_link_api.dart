import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SongLinkResult {
  final Map<String, String> platformUrls;
  final String? title;
  final String? artistName;
  final String? thumbnailUrl;

  SongLinkResult({
    required this.platformUrls,
    this.title,
    this.artistName,
    this.thumbnailUrl,
  });
}

class SongLinkApiService {
  static const String _apiUrl = 'https://api.song.link/v1-alpha.1/links';

  static const Map<String, String> _platformMap = {
    'spotify': 'spotify',
    'appleMusic': 'apple_music',
    'youtubeMusic': 'youtube_music',
    'youtube': 'youtube',
    'amazonMusic': 'amazon_music',
    'amazon': 'amazon_music',
    'tidal': 'tidal',
  };

  static Future<SongLinkResult?> fetchLinks(String url) async {
    // Try Odesli API first
    final result = await _fetchFromOdesli(url);
    if (result != null && result.platformUrls.isNotEmpty) {
      debugPrint('SongLinkAPI: Odesli returned ${result.platformUrls.length} platforms');
      return result;
    }

    // Fallback: scrape song.link page
    debugPrint('SongLinkAPI: Odesli failed, trying song.link scrape...');
    return _fetchFromSongLinkPage(url);
  }

  static Future<SongLinkResult?> _fetchFromOdesli(String url) async {
    try {
      final uri = Uri.parse(_apiUrl).replace(
        queryParameters: {'url': url, 'userCountry': 'IN'},
      );

      debugPrint('OdesliAPI: Fetching $uri');
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'MusicShare/1.0',
          'Accept': 'application/json',
        },
      );

      debugPrint('OdesliAPI: HTTP ${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('OdesliAPI: Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('OdesliAPI: Response keys: ${data.keys}');

      final linksByPlatform = data['linksByPlatform'] as Map<String, dynamic>?;
      if (linksByPlatform == null) {
        debugPrint('OdesliAPI: No linksByPlatform in response');
        return null;
      }

      debugPrint('OdesliAPI: Platform keys in response: ${linksByPlatform.keys}');

      final platformUrls = <String, String>{};
      for (final entry in linksByPlatform.entries) {
        final mappedId = _platformMap[entry.key];
        debugPrint('OdesliAPI: Platform ${entry.key} -> $mappedId');
        if (mappedId != null) {
          final platformData = entry.value as Map<String, dynamic>;
          final linkUrl = platformData['url'] as String?;
          if (linkUrl != null && linkUrl.isNotEmpty) {
            platformUrls[mappedId] = linkUrl;
            debugPrint('OdesliAPI: Mapped $mappedId -> $linkUrl');
          }
        }
      }

      debugPrint('OdesliAPI: Total mapped platforms: ${platformUrls.length}');

      String? title;
      String? artistName;
      String? thumbnailUrl;
      final entities = data['entitiesByUniqueId'] as Map<String, dynamic>?;
      if (entities != null) {
        final firstEntity = entities.values.firstOrNull as Map<String, dynamic>?;
        if (firstEntity != null) {
          title = firstEntity['title'] as String?;
          artistName = firstEntity['artistName'] as String?;
          thumbnailUrl = firstEntity['thumbnailUrl'] as String?;
          debugPrint('OdesliAPI: Song info: $title - $artistName');
        }
      }

      return SongLinkResult(
        platformUrls: platformUrls,
        title: title,
        artistName: artistName,
        thumbnailUrl: thumbnailUrl,
      );
    } catch (e) {
      debugPrint('OdesliAPI error: $e');
      return null;
    }
  }

  static Future<SongLinkResult?> _fetchFromSongLinkPage(String url) async {
    try {
      // Construct song.link page URL
      final songLinkUrl = 'https://song.link/$url';
      debugPrint('SongLinkScrape: Fetching $songLinkUrl');

      final response = await http.get(
        Uri.parse(songLinkUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
          'Accept': 'text/html',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('SongLinkScrape: HTTP ${response.statusCode}');
        return null;
      }

      final html = response.body;
      debugPrint('SongLinkScrape: HTML length: ${html.length}');

      // Extract platform links from the song.link page
      // The page contains JSON-LD with all platform links
      final platformUrls = <String, String>{};

      // Try JSON-LD first
      final jsonLdMatch = RegExp(
        r'<script[^>]+type="application/ld\+json"[^>]*>(.*?)</script>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(html);

      if (jsonLdMatch != null) {
        try {
          final jsonLd = jsonDecode(jsonLdMatch.group(1)!) as Map<String, dynamic>;
          debugPrint('SongLinkScrape: JSON-LD found, keys: ${jsonLd.keys}');
        } catch (_) {}
      }

      // Extract from og:url and other meta tags
      final metaPatterns = {
        'spotify': RegExp(r'https://open\.spotify\.com/track/[a-zA-Z0-9]+'),
        'appleMusic': RegExp("https://music\\.apple\\.com/[^\\s\"']+"),
        'youtube': RegExp(r'https://(?:youtu\.be/|www\.youtube\.com/watch\?v=)[a-zA-Z0-9_-]+'),
        'tidal': RegExp(r'https://listen\.tidal\.com/track/\d+'),
      };

      for (final entry in metaPatterns.entries) {
        final match = entry.value.firstMatch(html);
        if (match != null) {
          String linkUrl = match.group(0)!;
          // Remove any trailing characters
          linkUrl = linkUrl.replaceAll(RegExp(r'[^\w\d/:.\-?=&%+#]+$'), '');
          platformUrls[entry.key] = linkUrl;
          debugPrint('SongLinkScrape: Found ${entry.key} -> $linkUrl');
        }
      }

      if (platformUrls.isEmpty) {
        debugPrint('SongLinkScrape: No platform links found');
        return null;
      }

      // Try to extract song title from the page
      String? title;
      final ogTitle = RegExp(
        r'<meta[^>]+property="og:title"[^>]+content="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(html);
      if (ogTitle != null) {
        title = ogTitle.group(1)!.trim();
        debugPrint('SongLinkScrape: OG title: $title');
      }

      return SongLinkResult(
        platformUrls: platformUrls,
        title: title,
        artistName: null,
      );
    } catch (e) {
      debugPrint('SongLinkScrape error: $e');
      return null;
    }
  }
}