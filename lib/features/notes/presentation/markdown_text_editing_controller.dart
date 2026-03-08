import 'package:flutter/material.dart';

class MarkdownTextEditingController extends TextEditingController {
  MarkdownTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final defaultStyle = style ?? const TextStyle();
    if (text.isEmpty) return TextSpan(style: defaultStyle, text: text);

    return _parseText(text, defaultStyle, true, context);
  }

  TextSpan _parseText(String text, TextStyle style, bool isRoot, BuildContext context) {
    if (text.isEmpty) return TextSpan(text: "");

    final String rootPattern = r'(^### [^\n]+)|(^## [^\n]+)|(^# [^\n]+)|(```.*?```)|(\*\*\*.*?\*\*\*|___.*?___)|(\*\*.*?\*\*|__.*?__)|(\*.*?\*|_[^_]+?_)|(`.*?`)|(<u>.*?</u>)';
    final String childPattern = r'()()()(```.*?```)|(\*\*\*.*?\*\*\*|___.*?___)|(\*\*.*?\*\*|__.*?__)|(\*.*?\*|_[^_]+?_)|(`.*?`)|(<u>.*?</u>)';

    final pattern = RegExp(
      isRoot ? rootPattern : childPattern,
      multiLine: true,
      dotAll: true,
    );

    final matches = pattern.allMatches(text);
    if (matches.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start), style: style));
      }

      final matchText = match.group(0)!;
      TextStyle inlineStyle = style;

      if (match.group(1) != null) { // ###
        inlineStyle = inlineStyle.copyWith(fontSize: (style.fontSize ?? 14) * 1.1, fontWeight: FontWeight.bold);
        spans.add(TextSpan(text: matchText, style: inlineStyle));
      } else if (match.group(2) != null) { // ##
        inlineStyle = inlineStyle.copyWith(fontSize: (style.fontSize ?? 14) * 1.3, fontWeight: FontWeight.bold);
        spans.add(TextSpan(text: matchText, style: inlineStyle));
      } else if (match.group(3) != null) { // #
        inlineStyle = inlineStyle.copyWith(fontSize: (style.fontSize ?? 14) * 1.5, fontWeight: FontWeight.bold);
        spans.add(TextSpan(text: matchText, style: inlineStyle));
      } else if (match.group(4) != null) { // ``` (multiline code)
        inlineStyle = inlineStyle.copyWith(
          fontFamily: 'monospace',
          color: Colors.blueGrey,
        );
        spans.add(TextSpan(text: matchText, style: inlineStyle));
      } else if (match.group(5) != null) { // *** or ___
        inlineStyle = inlineStyle.copyWith(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic);
        final innerText = matchText.substring(3, matchText.length - 3);
        final marker = matchText.substring(0, 3);
        spans.addAll([
          TextSpan(text: marker, style: inlineStyle),
          _parseText(innerText, inlineStyle, false, context),
          TextSpan(text: marker, style: inlineStyle),
        ]);
      } else if (match.group(6) != null) { // ** or __
        inlineStyle = inlineStyle.copyWith(fontWeight: FontWeight.bold);
        final innerText = matchText.substring(2, matchText.length - 2);
        final marker = matchText.substring(0, 2);
        spans.addAll([
          TextSpan(text: marker, style: inlineStyle),
          _parseText(innerText, inlineStyle, false, context),
          TextSpan(text: marker, style: inlineStyle),
        ]);
      } else if (match.group(7) != null) { // * or _
        inlineStyle = inlineStyle.copyWith(fontStyle: FontStyle.italic);
        final innerText = matchText.substring(1, matchText.length - 1);
        final marker = matchText.substring(0, 1);
        spans.addAll([
          TextSpan(text: marker, style: inlineStyle),
          _parseText(innerText, inlineStyle, false, context),
          TextSpan(text: marker, style: inlineStyle),
        ]);
      } else if (match.group(8) != null) { // ` (inline code)
        inlineStyle = inlineStyle.copyWith(
          fontFamily: 'monospace',
          color: Colors.blueGrey,
        );
        spans.add(TextSpan(text: matchText, style: inlineStyle));
      } else if (match.group(9) != null) { // <u>
        inlineStyle = inlineStyle.copyWith(decoration: TextDecoration.underline);
        final innerText = matchText.substring(3, matchText.length - 4);
        spans.addAll([
          TextSpan(text: '<u>', style: inlineStyle),
          _parseText(innerText, inlineStyle, false, context),
          TextSpan(text: '</u>', style: inlineStyle),
        ]);
      } else {
        spans.add(TextSpan(text: matchText, style: inlineStyle));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd), style: style));
    }

    return TextSpan(children: spans, style: style);
  }
}
