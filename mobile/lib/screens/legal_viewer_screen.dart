import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/legal.dart';

/// Renders a bundled legal markdown document (lightweight — headings, bullets,
/// paragraphs). Enough for readable ToS/Privacy without a markdown package.
class LegalViewerScreen extends StatelessWidget {
  const LegalViewerScreen({super.key, required this.doc});
  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(doc.title, style: AppType.h3),
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(doc.asset),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            physics: const BouncingScrollPhysics(),
            children: _render(snap.data!),
          );
        },
      ),
    );
  }

  List<Widget> _render(String md) {
    final widgets = <Widget>[];
    for (final raw in md.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
      } else if (line.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(line.substring(2), style: AppType.h2.copyWith(fontSize: 22)),
        ));
      } else if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Text(line.substring(3), style: AppType.h3),
        ));
      } else if (line.startsWith('- ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: AppType.body),
              Expanded(child: Text(_plain(line.substring(2)), style: AppType.body)),
            ],
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(_plain(line), style: AppType.body),
        ));
      }
    }
    return widgets;
  }

  // Strip simple markdown emphasis markers for plain rendering.
  String _plain(String s) => s.replaceAll('**', '').replaceAll('_', '');
}
