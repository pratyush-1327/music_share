import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MetadataFetcher {
  static Future<Map<String, String?>> fetchMetadata(String url) async {
    try {
      debugPrint('MetadataFetcher: Fetching $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('MetadataFetcher: HTTP ${response.statusCode}');
        return {'title': null, 'artist': null};
      }

      final html = response.body;

      String? title = _extractOgTitle(html) ?? _extractHtmlTitle(html);
      debugPrint('MetadataFetcher: Extracted title: $title');

      if (title == null || title.isEmpty) {
        return {'title': null, 'artist': null};
      }

      return _parseTitle(title, url);
    } catch (e) {
      debugPrint('MetadataFetcher error: $e');
      return {'title': null, 'artist': null};
    }
  }

  static String? _extractHtmlTitle(String html) {
    final match = RegExp(r'<title>(.+?)</title>', caseSensitive: false, dotAll: true).firstMatch(html);
    if (match != null) {
      String title = match.group(1)!.trim();
      title = title.replaceAll(RegExp(r'\s+'), ' ');
      return title;
    }
    return null;
  }

  static String? _extractOgTitle(String html) {
    // Match double-quoted og:title
    final matchDouble = RegExp(
      r'<meta[^>]+property="(?:og:title|twitter:title)"[^>]+content="([^"]+)"',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (matchDouble != null) {
      return matchDouble.group(1)!.trim().replaceAll(RegExp(r'\s+'), ' ');
    }
    // Match single-quoted og:title
    final matchSingle = RegExp(
      r"<meta[^>]+property='(?:og:title|twitter:title)'[^>]+content='([^']+)'",
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (matchSingle != null) {
      return matchSingle.group(1)!.trim().replaceAll(RegExp(r'\s+'), ' ');
    }
    return null;
  }

  static Map<String, String?> _parseTitle(String title, String url) {
    String? song;
    String? artist;

    // Normalize: decode HTML entities
    title = title.replaceAll('&amp;', '&').replaceAll('&#39;', "'").replaceAll('&quot;', '"');

    // Strip service suffixes
    String clean = title;
    clean = clean.replaceAll(RegExp(r'\s*[-–|]\s*(YouTube Music|YouTube|Spotify|Apple Music|SoundCloud|Deezer|Amazon Music|Tidal)$', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'\s*[-–|]\s*(YouTube Music|YouTube)\s*$', caseSensitive: false), '');
    clean = clean.trim();

    // Strip parenthetical suffixes like "(Official Video)", "(Audio)", "(Lyrics)", etc.
    clean = clean.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
    clean = clean.replaceAll(RegExp(r'\s*\[[^\]]*\]\s*$'), '').trim();

    // Try: "Song - Artist" or "Song – Artist"
    final dashMatch = RegExp(r'^(.+?)\s*[-–|]\s*(.+)$').firstMatch(clean);
    if (dashMatch != null) {
      song = dashMatch.group(1)!.trim();
      artist = dashMatch.group(2)!.trim();
      return {'title': song, 'artist': artist};
    }

    // Try: "Artist - Song" (detect by common patterns)
    final reverseMatch = RegExp(r'^(.+?)\s*[-–|]\s*(.+)$').firstMatch(clean);
    if (reverseMatch != null) {
      artist = reverseMatch.group(1)!.trim();
      song = reverseMatch.group(2)!.trim();
      return {'title': song, 'artist': artist};
    }

    // Try: "Song by Artist"
    final byMatch = RegExp(r'^(.+?)\s+by\s+(.+)$', caseSensitive: false).firstMatch(clean);
    if (byMatch != null) {
      song = byMatch.group(1)!.trim();
      artist = byMatch.group(2)!.trim();
      return {'title': song, 'artist': artist};
    }

    // Try: "Artist: Song"
    final colonMatch = RegExp(r'^(.+?):\s*(.+)$').firstMatch(clean);
    if (colonMatch != null) {
      artist = colonMatch.group(1)!.trim();
      song = colonMatch.group(2)!.trim();
      return {'title': song, 'artist': artist};
    }

    // Fallback: use the whole cleaned title as the song name
    return {'title': clean, 'artist': null};
  }
}