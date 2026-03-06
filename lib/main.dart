import 'package:flutter/material.dart';
import 'package:studypdf/app.dart';
import 'package:studypdf/external_panel_app.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  if (args.isNotEmpty && args.first == 'multi_window') {
    runApp(ExternalPanelApp(payloadJson: args.length > 2 ? args[2] : '{}'));
    return;
  }
  runApp(const StudyPdfApp());
}
