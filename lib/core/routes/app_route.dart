import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../view/redirection.dart';
import '../../view/screens/collection/collection_screen.dart';
import '../../view/screens/collection/viewer_screen.dart';
import '../../view/screens/editor/photo_editor_screen.dart';
import '../../view/screens/main_screen.dart';
import '../../view/screens/settings/privacy_policy_screen.dart';
import '../../view/screens/settings/settings_screen.dart';
import '../../view/screens/sharing/sharing_screen.dart';
import 'swipeable_page_route.dart';

part 'app_route.g.dart';

class RedirectionExtra {
  final List<String> routes;
  final Map<String, dynamic> params;
  const RedirectionExtra({this.routes = const [], this.params = const {}});
}

class ViewerExtra {
  final List<AssetEntity> assets;
  final int index;
  const ViewerExtra({required this.assets, required this.index});
}

@TypedGoRoute<RedirectionRoute>(path: '/')
class RedirectionRoute extends GoRouteData with $RedirectionRoute {
  const RedirectionRoute({this.$extra});

  final RedirectionExtra? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) => const Redirection();
}

@TypedGoRoute<MainRoute>(
  path: '/main',
  routes: [
    TypedGoRoute<SettingsRoute>(path: 'settings'),
    TypedGoRoute<PrivacyPolicyRoute>(path: 'privacy'),
    TypedGoRoute<EditorRoute>(path: 'editor'),
    TypedGoRoute<SharingRoute>(path: 'sharing'),
    TypedGoRoute<CollectionRoute>(
      path: 'collection',
      routes: [TypedGoRoute<ViewerRoute>(path: 'viewer')],
    ),
  ],
)
class MainRoute extends GoRouteData with $MainRoute {
  const MainRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const MainScreen();
}

class SettingsRoute extends GoRouteData with $SettingsRoute {
  const SettingsRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => SwipeablePage<void>(builder: (context) => const SettingsScreen());
}

/// The editor draws with one finger: no swipe-back gesture there.
class PrivacyPolicyRoute extends GoRouteData with $PrivacyPolicyRoute {
  const PrivacyPolicyRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => SwipeablePage<void>(builder: (context) => const PrivacyPolicyScreen());
}

class EditorRoute extends GoRouteData with $EditorRoute {
  const EditorRoute({required this.$extra});

  /// Path of the photo to edit.
  final String $extra;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => CustomTransitionPage<void>(
    key: state.pageKey,
    child: PhotoEditorScreen(sourcePath: $extra),
    transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
  );
}

class SharingRoute extends GoRouteData with $SharingRoute {
  const SharingRoute({required this.$extra});

  /// Path of the saved photo.
  final String $extra;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => SwipeablePage<void>(builder: (context) => SharingScreen(path: $extra));
}

class CollectionRoute extends GoRouteData with $CollectionRoute {
  const CollectionRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => SwipeablePage<void>(builder: (context) => const CollectionScreen());
}

class ViewerRoute extends GoRouteData with $ViewerRoute {
  const ViewerRoute({required this.$extra});

  final ViewerExtra $extra;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => CustomTransitionPage<void>(
    key: state.pageKey,
    child: ViewerScreen(assets: $extra.assets, initialIndex: $extra.index),
    transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
  );
}
