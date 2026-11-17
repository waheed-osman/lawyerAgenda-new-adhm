import 'dart:typed_data';

/// تنزيل ملف من المتصفح (يعمل على الويب فقط؛ نسخة الويب تستبدل هذا الملف أثناء البناء).
void downloadBytes(String name, Uint8List bytes, String mime) {
  throw UnsupportedError('التنزيل المباشر متاح في نسخة الويب فقط');
}
