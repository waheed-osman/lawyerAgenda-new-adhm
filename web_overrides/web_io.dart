// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// تنزيل ملف من المتصفح.
void downloadBytes(String name, Uint8List bytes, String mime) {
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final a = html.AnchorElement(href: url)..download = name;
  html.document.body?.append(a);
  a.click();
  a.remove();
  html.Url.revokeObjectUrl(url);
}
