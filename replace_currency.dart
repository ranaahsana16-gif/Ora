import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    try {
      String content = file.readAsStringSync();
      if (content.contains(r'\$')) {
        // Replace \$ with Rs.
        content = content.replaceAll(r'\$', 'Rs. ');
        file.writeAsStringSync(content);
        // ignore: avoid_print
        print('Currency replacement complete');
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error replacing currency: $e');
    }
  }
}
