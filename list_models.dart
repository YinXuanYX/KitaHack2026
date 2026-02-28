import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final apiKey = 'AIzaSyDr5mDEMTBP3QIqqnvIdyrQb5z6m4dO-mc';
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=\$apiKey');
  final request = await HttpClient().getUrl(url);
  final response = await request.close();
  final stringData = await response.transform(utf8.decoder).join();
  print(stringData);
  exit(0);
}
