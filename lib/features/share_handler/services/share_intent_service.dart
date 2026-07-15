import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/music_services.dart';
import '../data/models/music_link.dart';
import '../data/repositories/link_parser.dart';
import '../data/metadata_fetcher.dart';
import '../data/song_link_api.dart';
import '../data/platform_resolver.dart';

class ShareIntentService extends ChangeNotifier {
  ShareIntentService() {
    _initIntentListeners();
  }

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription? _intentSub;
  bool _isProcessing = false;
  MusicLink? _currentLink;
  SharedMediaFile? _sharedFile;

  MusicLink? get currentLink => _currentLink;
  bool get isProcessing => _isProcessing;
  SharedMediaFile? get sharedFile => _sharedFile;

  void _initIntentListeners() {
    if (Platform.isIOS) return;

    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (value) {
        if (value.isNotEmpty) {
          final file = value.first;
          _sharedFile = file;
          
          // Handle text shares (type = "text" or "url")
          if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
            debugPrint('getMediaStream (text): ${file.path}');
            handleSharedText([file.path]);
          } else {
            // Handle media files (images, videos, etc.)
            debugPrint('getMediaStream (media): ${file.toMap()}');
            handleSharedFile(file);
          }
        }
      },
      onError: (err) {
        debugPrint('getMediaStream error: $err');
      },
    );

    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        final file = value.first;
        _sharedFile = file;
        
        // Handle text shares (type = "text" or "url")
        if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
          debugPrint('getInitialMedia (text): ${file.path}');
          handleSharedText([file.path]);
        } else {
          // Handle media files (images, videos, etc.)
          debugPrint('getInitialMedia (media): ${file.toMap()}');
          handleSharedFile(file);
        }
      }
    });
  }

  String? _extractUrl(String text) {
    try {
      final match = RegExp(r'(https?:\/\/[^\s]+)').firstMatch(text);
      final url = match?.group(1);
      debugPrint('ShareIntentService._extractUrl: text=$text, url=$url');
      return url;
    } catch (e) {
      debugPrint('Error extracting URL: $e');
      return null;
    }
  }

  Map<String, String?> _extractMetadata(String rawText) {
    String? title;
    String? artist;

    try {
      // Pattern 1: "Listen to ... by ..." (Apple Music, Spotify)
      final listenToMatch = RegExp(r'listen\s+to\s+(.+?)\s+by\s+(.+?)(?:\s+on\s+|\s+https?:|$)', caseSensitive: false).firstMatch(rawText);
      if (listenToMatch != null) {
        title = listenToMatch.group(1);
        artist = listenToMatch.group(2);
      }

      // Pattern 2: "Check out ... by ..."
      if (title == null) {
        final checkOutMatch = RegExp(r'check\s+out\s+(.+?)\s+by\s+(.+?)(?:\s+on\s+|\s+https?:|$)', caseSensitive: false).firstMatch(rawText);
        if (checkOutMatch != null) {
          title = checkOutMatch.group(1);
          artist = checkOutMatch.group(2);
        }
      }

      // Pattern 3: "Title - Artist" format
      if (title == null) {
        final dashMatch = RegExp(r'^(.+?)\s*[-–]\s*(.+?)(?:\s+on\s+|\s+https?:|$)').firstMatch(rawText);
        if (dashMatch != null) {
          title = dashMatch.group(1);
          artist = dashMatch.group(2);
        }
      }

      // Pattern 4: "Artist - Title" format
      if (title == null) {
        final artistDashMatch = RegExp(r'^(.+?)\s*[-–]\s*(.+?)(?:\s+on\s+|\s+https?:|$)').firstMatch(rawText);
        if (artistDashMatch != null) {
          artist = artistDashMatch.group(1);
          title = artistDashMatch.group(2);
        }
      }

      // Pattern 5: "Title by Artist" format
      if (title == null) {
        final byMatch = RegExp(r'^(.+?)\s+by\s+(.+?)(?:\s+on\s+|\s+https?:|$)', caseSensitive: false).firstMatch(rawText);
        if (byMatch != null) {
          title = byMatch.group(1);
          artist = byMatch.group(2);
        }
      }

      // Pattern 6: "Artist: Title" format
      if (title == null) {
        final colonMatch = RegExp(r'^(.+?):\s*(.+?)(?:\s+on\s+|\s+https?:|$)').firstMatch(rawText);
        if (colonMatch != null) {
          artist = colonMatch.group(1);
          title = colonMatch.group(2);
        }
      }
    } catch (e) {
      debugPrint('Error extracting metadata: $e');
    }

    return {
      'title': title?.trim(),
      'artist': artist?.trim(),
    };
  }

  void _navigateTo(String routeName, {bool replace = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = navigatorKey.currentState;
      if (state != null) {
        if (replace) {
          state.pushReplacementNamed(routeName);
        } else {
          // Pop back to root before pushing processing to keep stack clean
          state.popUntil((route) => route.isFirst);
          state.pushNamed(routeName);
        }
      }
    });
  }

  void _popScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = navigatorKey.currentState;
      if (state != null) {
        state.pop();
      }
    });
  }

  Future<void> handleSharedText(List<String> textList) async {
    if (_isProcessing) return;
    if (textList.isEmpty) return;
    await _processSharedText(textList.first);
  }

  Future<void> handleSharedUrl(String url) async {
    if (_isProcessing) return;
    await _processSharedText(url);
  }

  Future<void> handleSharedFile(SharedMediaFile file) async {
    if (_isProcessing) return;
    _sharedFile = file;
    _showSnackBar('Files are not supported yet');
  }

  Future<void> _processSharedText(String rawText) async {
    _isProcessing = true;
    _currentLink = null;
    notifyListeners();

    _navigateTo('/processing');

    try {
      final url = _extractUrl(rawText);
      if (url == null) {
        debugPrint('No valid URL found in text: $rawText');

        // Try to extract metadata from text without URL
        final metadata = _extractMetadata(rawText);
        if (metadata['title'] != null || metadata['artist'] != null) {
          debugPrint('Using text as song info: $metadata');
          try {
            await Future.delayed(const Duration(milliseconds: 500));
            _currentLink = LinkParser.parse(
              'https://example.com/music', // Dummy URL
              trackName: metadata['title'],
              artistName: metadata['artist'],
            );
          } catch (e) {
            debugPrint('Error parsing text: $e');
            _showSnackBar('Failed to process text');
            _currentLink = null;
          }
        } else {
          _showSnackBar('Invalid URL or text');
        }

        _isProcessing = false;
        notifyListeners();

        if (_currentLink != null) {
          _navigateTo('/result', replace: true);
        } else {
          _popScreen();
        }
        return;
      }

      debugPrint('Extracted URL: $url');

      // Step 1: Try to get direct links from SongLink API
      debugPrint('Fetching direct links from SongLink API...');
      final songLinkResult = await SongLinkApiService.fetchLinks(url);

      if (songLinkResult != null && songLinkResult.platformUrls.isNotEmpty) {
        debugPrint('SongLink API returned ${songLinkResult.platformUrls.length} platforms');
        final sourceService = MusicServices.detectService(url);
        final trackId = sourceService?.extractIdFromUrl(url);
        final trackName = songLinkResult.title;
        final artistName = songLinkResult.artistName;

        final availableLinks = <ServiceLink>[];
        final addedIds = <String>{};
        for (final entry in songLinkResult.platformUrls.entries) {
          for (final service in MusicServices.allServices) {
            if (service.id == entry.key) {
              availableLinks.add(ServiceLink(service: service, url: entry.value));
              addedIds.add(service.id);
              break;
            }
          }
        }

        // For platforms missing from Odesli, try PlatformResolver
        for (final service in MusicServices.allServices) {
          if (addedIds.contains(service.id)) continue;
          final resolved = await PlatformResolver.resolvePlatform(
            service.id, trackName, artistName,
          );
          if (resolved != null) {
            availableLinks.add(ServiceLink(service: service, url: resolved));
            addedIds.add(service.id);
            debugPrint('PlatformResolver: Found ${service.id} -> $resolved');
          } else if (trackName != null && trackName.isNotEmpty) {
            final searchUrl = MusicServices.generateSearchLink(service, trackName, artistName);
            if (searchUrl.isNotEmpty) {
              availableLinks.add(ServiceLink(service: service, url: searchUrl));
              addedIds.add(service.id);
            }
          }
        }

        debugPrint('Final available platforms (${availableLinks.length}): '
            '${availableLinks.map((l) => l.service.id).join(', ')}');

        _currentLink = MusicLink(
          originalUrl: url,
          sourceService: sourceService,
          trackId: trackId,
          trackName: songLinkResult.title,
          artistName: songLinkResult.artistName,
          availableLinks: availableLinks,
        );
      } else {
        debugPrint('SongLink API failed, resolving via PlatformResolver...');
        String? trackName;
        String? artistName;

        final textMetadata = _extractMetadata(rawText);
        trackName = textMetadata['title'];
        artistName = textMetadata['artist'];

        if (trackName == null && artistName == null) {
          final pageMetadata = await MetadataFetcher.fetchMetadata(url);
          trackName = pageMetadata['title'];
          artistName = pageMetadata['artist'];
        }

        final link = LinkParser.parse(url, trackName: trackName, artistName: artistName);
        if (link.sourceService != null) {
          final availableLinks = <ServiceLink>[link.sourceLink];
          final addedIds = {link.sourceService!.id};

          for (final service in MusicServices.allServices) {
            if (addedIds.contains(service.id)) continue;
            final resolved = await PlatformResolver.resolvePlatform(
              service.id, trackName, artistName,
            );
            if (resolved != null) {
              availableLinks.add(ServiceLink(service: service, url: resolved));
              addedIds.add(service.id);
            } else if (trackName != null && trackName.isNotEmpty) {
              final searchUrl = MusicServices.generateSearchLink(service, trackName, artistName);
              if (searchUrl.isNotEmpty) {
                availableLinks.add(ServiceLink(service: service, url: searchUrl));
                addedIds.add(service.id);
              }
            }
          }

          _currentLink = MusicLink(
            originalUrl: url,
            sourceService: link.sourceService,
            trackId: link.trackId,
            trackName: trackName,
            artistName: artistName,
            availableLinks: availableLinks,
          );
        } else {
          _currentLink = link;
        }
      }

      debugPrint('Parsed link: ${_currentLink?.displayTitle}');
      debugPrint('Source service: ${_currentLink?.sourceService?.name}');
      debugPrint('Available links: ${_currentLink?.availableLinks.length}');
    } catch (e) {
      debugPrint('Error in _processSharedText: $e');
      _showSnackBar('Failed to process link');
      _currentLink = null;
    } finally {
      _isProcessing = false;
      notifyListeners();

      if (_currentLink != null) {
        _navigateTo('/result', replace: true);
      } else {
        _popScreen();
      }
    }
  }

  Future<void> openLinkInService(MusicService service) async {
    if (_currentLink == null) return;

    for (final link in _currentLink!.availableLinks) {
      if (link.service.id == service.id) {
        final uri = Uri.parse(link.url);
        if (!await launchUrl(uri)) {
          _showSnackBar('Failed to open link');
        }
        break;
      }
    }
  }

  Future<void> shareAllLinks() async {
    if (_currentLink == null) return;

    final message = _currentLink!.generateShareMessage();
    try {
      final result = await SharePlus.instance.share(ShareParams(text: message));

      if (result.status == ShareResultStatus.success) {
        debugPrint('Shared successfully');
      } else if (result.status == ShareResultStatus.dismissed) {
        debugPrint('Share was dismissed');
      } else if (result.status == ShareResultStatus.unavailable) {
        debugPrint('Sharing not available');
      }
    } catch (e) {
      debugPrint('Error sharing: $e');
      _showSnackBar('Failed to share');
    }
  }

  Future<void> shareIndividualLink(ServiceLink link) async {
    if (_currentLink == null) return;

    final message = '🎵 ${_currentLink!.displayTitle}\n🔗 ${link.service.name}: ${link.url}\n\nShared via PulseShare';
    try {
      final result = await SharePlus.instance.share(ShareParams(text: message));
      if (result.status == ShareResultStatus.success) {
        debugPrint('Shared individual link successfully');
      }
    } catch (e) {
      debugPrint('Error sharing individual link: $e');
      _showSnackBar('Failed to share link');
    }
  }

  void _showSnackBar(String message) {
    debugPrint('SnackBar: $message');
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }
}