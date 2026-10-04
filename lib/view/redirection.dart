import 'package:another_flutter_splash_screen/another_flutter_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/providers/navigation/redirection_provider.dart';
import 'themes/app_theme.dart';

/// Redirection screen
class Redirection extends ConsumerStatefulWidget {
  const Redirection({super.key});

  @override
  RedirectionState createState() => RedirectionState();
}

class RedirectionState extends ConsumerState<Redirection> {
  @override
  void initState() {
    super.initState();

    FlutterNativeSplash.remove();
  }

  /// The lens over the native splash's background, then [redirectionProvider] goes on.
  @override
  Widget build(BuildContext context) {
    ref.watch(redirectionProvider);

    return FlutterSplashScreen(
      useImmersiveMode: true,
      duration: const Duration(milliseconds: 1000),
      backgroundColor: AppTheme.pickColor(
        light: Colors.white,
        dark: const Color(0xFF262626),
      ),
      splashScreenBody: Center(
        child: SvgPicture.asset('assets/images/lens.svg', width: 168),
      ),
      onInit: () {},
      onEnd: () {
        ref.read(redirectionProvider.notifier).redirect(ref);
      },
    );
  }
}
