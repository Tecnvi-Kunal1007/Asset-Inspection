import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../screens/call_screen.dart';

class DeepLinkService {
  static late AppLinks _appLinks;
  static GlobalKey<NavigatorState>? _navigatorKey;

  static Future<void> init(BuildContext context, {GlobalKey<NavigatorState>? navigatorKey}) async {
    _navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>();
    if (kIsWeb) {
      try {
        final currentUrl = Uri.base;
        final channel = currentUrl.queryParameters['channel'];
        final token = currentUrl.queryParameters['token'];

        print('Deep link detected - Channel: $channel, Token: ${token != null ? 'present' : 'null'}');

        if (channel != null && channel.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 500));
          final navigatorContext = _navigatorKey?.currentContext ?? context;
          if (navigatorContext.mounted) {
            Navigator.pushReplacement(
              navigatorContext,
              MaterialPageRoute(
                builder: (context) => CallScreen.withJoinConfirmation(
                  channelName: channel,
                  token: token,
                ),
              ),
            );
          } else {
            print('Navigator not ready, retrying in 1 second...');
            await Future.delayed(const Duration(seconds: 1));
            final retryContext = _navigatorKey?.currentContext ?? context;
            if (retryContext.mounted) {
              Navigator.pushReplacement(
                retryContext,
                MaterialPageRoute(
                  builder: (context) => CallScreen.withJoinConfirmation(
                    channelName: channel,
                    token: token,
                  ),
                ),
              );
            }
          }
        }
      } catch (e) {
        print('Error handling web deep link: $e');
      }
    } else {
      _appLinks = AppLinks();
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleLink(context, initialLink.toString());
      }
      _appLinks.uriLinkStream.listen((link) {
        _handleLink(context, link.toString());
      });
    }
  }

  static void _handleLink(BuildContext context, String link) {
    print('DeepLinkService: Handling mobile link: $link');
    final uri = Uri.parse(link);
    final channel = uri.queryParameters['channel'];
    final token = uri.queryParameters['token'];

    print('DeepLinkService: Parsed URI: $uri');
    print('DeepLinkService: Channel: $channel, Token: $token');

    if (channel != null) {
      print('DeepLinkService: Navigating to CallScreen with channel: $channel');
      final navigatorContext = _navigatorKey?.currentContext ?? context;
      Navigator.push(
        navigatorContext,
        MaterialPageRoute(
          builder: (context) => CallScreen.withJoinConfirmation(
            channelName: channel,
            token: token,
          ),
        ),
      );
    } else {
      print('DeepLinkService: No channel found in mobile link parameters');
    }
  }
}