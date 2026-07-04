import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/music_services.dart';
import '../data/models/music_link.dart';
import '../data/repositories/link_parser.dart';

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
          debugPrint('getMediaStream: ${file.toMap()}');
          _processSharedText(file.path);
        }
      },
      onError: (err) {
        debugPrint('getMediaDataStream error: $err');
      },
    );

    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        final file = value.first;
        _sharedFile = file;
        debugPrint('getInitialMedia: ${file.toMap()}');
        _processSharedText(file.path);
      }
    });
  }

  String? _extractUrl(String text) {
    final match = RegExp(r'(https?:\/\/[^\s]+)').firstMatch(text);
    return match?.group(1);
  }

  Map<String, String?> _extractMetadata(String rawText) {
    String? title;
    String? artist;

    // Pattern 1: Double quotes for title and "by ... (on|http|$)" for artist
    final quoteMatch = RegExp(r'"([^"]+)"').firstMatch(rawText);
    if (quoteMatch != null) {
      title = quoteMatch.group(1);
      final artistMatch = RegExp(r'by\s+([^\n]+?)\s+(?:on|https?:\/\/|$)').firstMatch(rawText);
      if (artistMatch != null) {
        artist = artistMatch.group(1);
      }
    }

    // Pattern 2: "Listen to ... by ... (on|http|$)" (Apple Music)
    if (title == null) {
      final listenToMatch = RegExp(r'Listen to\s+(.+?)\s+by\s+(.+?)\s+(?:on|https?:\/\/|$)').firstMatch(rawText);
      if (listenToMatch != null) {
        title = listenToMatch.group(1);
        artist = listenToMatch.group(2);
      }
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

    final url = _extractUrl(rawText);
    if (url == null) {
      debugPrint('No valid URL found in text: $rawText');
      _showSnackBar('Invalid URL');
      _isProcessing = false;
      notifyListeners();
      _popScreen();
      return;
    }

    final metadata = _extractMetadata(rawText);

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      _currentLink = LinkParser.parse(
        url,
        trackName: metadata['title'],
        artistName: metadata['artist'],
      );
    } catch (e) {
      debugPrint('Error parsing link: $e');
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

  void _showSnackBar(String message) {
    debugPrint('SnackBar: $message');
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }
}