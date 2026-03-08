import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class UnderlineSyntax extends md.InlineSyntax {
  UnderlineSyntax() : super(r'<u>(.*?)<\/u>');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('u', match[1]!));
    return true;
  }
}

class UnderlineBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Text(
      element.textContent,
      style: preferredStyle?.copyWith(decoration: TextDecoration.underline) ??
          const TextStyle(decoration: TextDecoration.underline),
    );
  }
}
