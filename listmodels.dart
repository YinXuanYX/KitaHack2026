import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final apiKey = 'AIzaSyBD24BGbR8W66gsiFEXvnMNyYqrziEcsL4';
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=\$apiKey');
  final request = await HttpClient().getUrl(url);
  final response = await request.close();
  final stringData = await response.transform(utf8.decoder).join();
  File('models_response.json').writeAsStringSync(stringData);
  print('Done');
  exit(0);
}
