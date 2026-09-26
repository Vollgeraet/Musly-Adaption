import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/detail/album_screen.dart';
import '../screens/detail/artist_screen.dart';
import '../screens/detail/genre_screen.dart';
import '../screens/detail/playlist_screen.dart';
import '../screens/media/album_collection_screen.dart';
import '../screens/media/song_collection_screen.dart';

class NavigationHelper {
  static final GlobalKey<NavigatorState> mobileNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> desktopNavigatorKey =
      GlobalKey<NavigatorState>();

  static final ValueNotifier<bool> isDesktopQueueOpen =
      ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isDesktopLyricsOpen =
      ValueNotifier<bool>(false);

  static void toggleDesktopQueue() {
    isDesktopQueueOpen.value = !isDesktopQueueOpen.value;
    if (isDesktopQueueOpen.value) {
      isDesktopLyricsOpen.value = false;
    }
  }

  static void toggleDesktopLyrics() {
    isDesktopLyricsOpen.value = !isDesktopLyricsOpen.value;
    if (isDesktopLyricsOpen.value) {
      isDesktopQueueOpen.value = false;
    }
  }

  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  static GlobalKey<NavigatorState> get navigatorKey =>
      isDesktop ? desktopNavigatorKey : mobileNavigatorKey;

  static Widget? _currentTopWidget;
  static int _lastPushTimestamp = 0;

  static bool _isSamePage(Widget a, Widget? b) {
    if (b == null) return false;
    if (a.runtimeType != b.runtimeType) return false;

    if (a is AlbumScreen && b is AlbumScreen) {
      return a.albumId == b.albumId;
    }
    if (a is PlaylistScreen && b is PlaylistScreen) {
      return a.playlistId == b.playlistId;
    }
    if (a is ArtistScreen && b is ArtistScreen) {
      return a.artistId == b.artistId;
    }
    if (a is GenreScreen && b is GenreScreen) {
      return a.genre == b.genre;
    }
    if (a is SongCollectionScreen && b is SongCollectionScreen) {
      return a.type == b.type && a.customTitle == b.customTitle;
    }
    if (a is AlbumCollectionScreen && b is AlbumCollectionScreen) {
      return a.type == b.type && a.customTitle == b.customTitle;
    }
    return true;
  }

  static Future<T?> push<T>(BuildContext context, Widget page) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_isSamePage(page, _currentTopWidget) ||
        (now - _lastPushTimestamp < 350 &&
            page.runtimeType == _currentTopWidget?.runtimeType)) {
      return Future.value(null);
    }

    _currentTopWidget = page;
    _lastPushTimestamp = now;

    final nav = navigatorKey.currentState;
    final route = MaterialPageRoute<T>(
      builder: (_) => page,
      settings:
          RouteSettings(name: page.runtimeType.toString(), arguments: page),
    );

    final future =
        nav != null ? nav.push<T>(route) : Navigator.of(context).push<T>(route);

    return future.then((res) {
      if (_currentTopWidget == page) {
        _currentTopWidget = null;
      }
      return res;
    });
  }

  static Future<T?> pushRoute<T>(BuildContext context, Route<T> route) {
    final nav = navigatorKey.currentState;
    if (nav != null) {
      return nav.push<T>(route);
    }
    return Navigator.of(context).push<T>(route);
  }

  static void pop<T>(BuildContext context, [T? result]) {
    _currentTopWidget = null;
    final nav = navigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop<T>(result);
    } else {
      Navigator.of(context).pop<T>(result);
    }
  }

  static void popUntil(
    BuildContext context,
    bool Function(Route<dynamic>) predicate,
  ) {
    _currentTopWidget = null;
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.popUntil(predicate);
    } else {
      Navigator.of(context).popUntil(predicate);
    }
  }

  static void Function(int)? _onTabChanged;

  static void registerTabChangeCallback(void Function(int) callback) {
    _onTabChanged = callback;
  }

  static void switchToTab(int index) {
    // Wichtig: Wenn gerade ein Detail-Screen (z. B. eine Playlist) über
    // den globalen Navigator gepusht ist, liegt er ÜBER dem MainScreen
    // und verdeckt ihn komplett. Ohne diesen popUntil ändert sich zwar
    // intern der Tab-Index, sichtbar wird das aber erst, wenn man
    // manuell zurücknavigiert - das war der gemeldete Bug.
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.popUntil((route) => route.isFirst);
    }
    _currentTopWidget = null;
    _onTabChanged?.call(index);
  }

  /// Wie [push], aber ohne Übergangsanimation (sofortiger Wechsel) -
  /// z. B. für das Öffnen einer Wiedergabeliste, die instant erscheinen
  /// soll statt mit der Standard-Slide-Transition.
  static Future<T?> pushInstant<T>(BuildContext context, Widget page) {
    _currentTopWidget = page;
    _lastPushTimestamp = DateTime.now().millisecondsSinceEpoch;

    final nav = navigatorKey.currentState;
    final route = PageRouteBuilder<T>(
      settings:
          RouteSettings(name: page.runtimeType.toString(), arguments: page),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => page,
    );

    final future =
        nav != null ? nav.push<T>(route) : Navigator.of(context).push<T>(route);

    return future.then((res) {
      if (_currentTopWidget == page) {
        _currentTopWidget = null;
      }
      return res;
    });
  }
}
