import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';

Future<void> main() async {
  final apiKey = 'AIzaSyBD24BGbR8W66gsiFEXvnMNyYqrziEcsL4';
  final models = ['gemini-1.5-flash', 'gemini-pro'];
  for (final modelName in models) {
    try {
      final model = GenerativeModel(model: modelName, apiKey: apiKey);
      final response = await model.generateContent([Content.text('Hello')]);
      print('$modelName SUCCESS: \${response.text}');
    } catch (e) {
      print('$modelName FAILED: $e');
    }
  }
  exit(0);
}
