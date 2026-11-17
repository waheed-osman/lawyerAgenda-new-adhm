import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// قاعدة البيانات على الويب: SQLite داخل المتصفح (WebAssembly) تُحفظ في بيانات الموقع.
Future<void> initDbFactory() async {
  databaseFactory = databaseFactoryFfiWeb;
}
