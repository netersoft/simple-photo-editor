import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/i18n/translations.g.dart';

/// The sources and licenses of the bundled stickers, illustrations and font.
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.t.sourcesAndCredits),
    ),
    body: FutureBuilder<String>(
      future: rootBundle.loadString('assets/docs/${LocaleSettings.instance.currentLocale.languageCode}/credits.html'),
      builder: (context, snapshot) => switch (snapshot.data) {
        final html? => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: HtmlWidget(
            html,
            textStyle: Theme.of(context).textTheme.bodyMedium,
            onTapUrl: (url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          ),
        ),
        null => const Center(child: CircularProgressIndicator()),
      },
    ),
  );
}
