import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';

Future<void> main() async {
  final apiKey = 'AIzaSyDr5mDEMTBP3QIqqnvIdyrQb5z6m4dO-mc';
  final models = ['gemini-1.5-flash', 'gemini-pro'];
  final f = File('results.txt');
  var out = '';
  for (final modelName in models) {
    try {
      final model = GenerativeModel(model: modelName, apiKey: apiKey);
      final response = await model.generateContent([Content.text('Hello')]);
      out += modelName + ' SUCCESS' + '\n';
    } catch (e) {
      out += modelName + ' FAILED: ' + e.toString() + '\n';
    }
  }
  await f.writeAsString(out);
  exit(0);
}
