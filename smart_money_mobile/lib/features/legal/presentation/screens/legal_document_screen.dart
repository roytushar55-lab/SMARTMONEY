import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/sm_colors.dart';
import '../../../../core/theme/sm_spacing.dart';
import '../../data/legal_documents.dart';

/// Shows a bundled legal document (Terms / Privacy Policy) inside the app.
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late final Future<String> _content = rootBundle.loadString(
    widget.document.assetPath,
  );

  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  Future<void> _openLink(String target) async {
    final document = LegalDocuments.fromLink(target);
    if (document != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LegalDocumentScreen(document: document),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(target);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(
        title: Text(widget.document.title),
        backgroundColor: colors.bgPrimary,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: FutureBuilder<String>(
        future: _content,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(SmSpacing.lg),
                child: Text(
                  'Unable to load this document.',
                  style: TextStyle(color: colors.danger),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return SelectionArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                SmSpacing.lg,
                SmSpacing.sm,
                SmSpacing.lg,
                SmSpacing.xl,
              ),
              children: _buildBlocks(snapshot.data!, colors),
            ),
          );
        },
      ),
    );
  }

  // A deliberately small Markdown subset: headings, bullets, numbered items,
  // horizontal rules, paragraphs, **bold**, *italic* and [links](target).
  List<Widget> _buildBlocks(String source, SmColors colors) {
    final blocks = <Widget>[];
    final base = TextStyle(
      color: colors.textPrimary,
      fontSize: 15,
      height: 1.5,
    );

    for (final rawLine in source.split('\n')) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) continue;

      if (line.trim() == '---') {
        blocks.add(Divider(height: 28, color: colors.border));
        continue;
      }

      final heading = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final size = const [22.0, 18.0, 16.0, 15.0][level - 1];
        blocks.add(
          Padding(
            padding: EdgeInsets.only(top: level == 1 ? 4 : 18, bottom: 6),
            child: Text(
              heading.group(2)!,
              style: base.copyWith(fontSize: size, fontWeight: FontWeight.w800),
            ),
          ),
        );
        continue;
      }

      final bullet = RegExp(r'^(\s*)[-*]\s+(.*)$').firstMatch(line);
      final numbered = RegExp(r'^(\s*)(\d+)\.\s+(.*)$').firstMatch(line);
      if (bullet != null || numbered != null) {
        final indent = (bullet?.group(1) ?? numbered!.group(1)!).length;
        final marker = bullet != null ? '•' : '${numbered!.group(2)}.';
        final text = bullet?.group(2) ?? numbered!.group(3)!;
        blocks.add(
          Padding(
            padding: EdgeInsets.only(left: 4.0 + indent * 6, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 22, child: Text(marker, style: base)),
                Expanded(child: _richText(text, base, colors)),
              ],
            ),
          ),
        );
        continue;
      }

      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _richText(line, base, colors),
        ),
      );
    }

    return blocks;
  }

  Widget _richText(String text, TextStyle base, SmColors colors) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|\[(.+?)\]\((.+?)\)');
    var cursor = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }

      if (match.group(1) != null) {
        spans.add(
          TextSpan(
            text: match.group(1),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else if (match.group(2) != null) {
        spans.add(
          TextSpan(
            text: match.group(2),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else {
        final target = match.group(4)!;
        final recognizer = TapGestureRecognizer()
          ..onTap = () => _openLink(target);
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: match.group(3),
            recognizer: recognizer,
            style: TextStyle(
              color: colors.primary,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }

      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(TextSpan(style: base, children: spans));
  }
}
