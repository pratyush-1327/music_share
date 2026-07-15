import 'package:flutter_test/flutter_test.dart';
import 'package:music_share/features/share_handler/data/song_link_api.dart';
import 'package:music_share/features/share_handler/data/metadata_fetcher.dart';
import 'package:music_share/features/share_handler/data/repositories/link_parser.dart';

void main() {
  test('Test Spotify Link Parsing with no metadata', () {
    final spotifyUrl = 'https://open.spotify.com/track/4cOdKLETKBW3PvgPWqT';
    final parsed = LinkParser.parse(spotifyUrl, trackName: null, artistName: null);
    
    print('Original URL: ${parsed.originalUrl}');
    print('Display Title: ${parsed.displayTitle}');
    print('Source Service: ${parsed.sourceService?.name}');
    print('Track ID: ${parsed.trackId}');
    print('Available links count: ${parsed.availableLinks.length}');
    for (final link in parsed.availableLinks) {
      print(' - ${link.service.name}: ${link.url}');
    }
  });

  test('Test SongLink API and Scraper', () async {
    final spotifyUrl = 'https://open.spotify.com/track/4cOdKLETKBW3PvgPWqT'; // Never Gonna Give You Up
    
    print('=== Testing SongLinkApiService ===');
    final apiResult = await SongLinkApiService.fetchLinks(spotifyUrl);
    if (apiResult != null) {
      print('API Title: ${apiResult.title}');
      print('API Artist: ${apiResult.artistName}');
      print('API Platform URLs: ${apiResult.platformUrls}');
    } else {
      print('API Result was null');
    }

    print('=== Testing MetadataFetcher ===');
    final meta = await MetadataFetcher.fetchMetadata(spotifyUrl);
    print('Meta Title: ${meta['title']}');
    print('Meta Artist: ${meta['artist']}');

    print('=== Testing LinkParser with metadata ===');
    final parsed = LinkParser.parse(spotifyUrl, trackName: meta['title'], artistName: meta['artist']);
    print('Parsed Display Title: ${parsed.displayTitle}');
    for (final link in parsed.availableLinks) {
      print(' - ${link.service.name}: ${link.url}');
    }
  });
}
