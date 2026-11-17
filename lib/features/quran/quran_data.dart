import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

class Surah {
  final int n;
  final String name;
  final bool meccan;
  final List<String> ayahs;
  Surah(this.n, this.name, this.meccan, this.ayahs);
  String get typeLabel => meccan ? 'مكية' : 'مدنية';
}

class QuranData {
  static List<Surah>? _cache;
  static List<List<String>>? _normCache;

  /// بداية كل جزء: (رقم السورة، رقم الآية).
  static const juzStarts = <(int, int)>[
    (1, 1), (2, 142), (2, 253), (3, 93), (4, 24), (4, 148), (5, 82), (6, 111), (7, 88), (8, 41),
    (9, 93), (11, 6), (12, 53), (15, 1), (17, 1), (18, 75), (21, 1), (23, 1), (25, 21), (27, 56),
    (29, 46), (33, 31), (36, 28), (39, 32), (41, 47), (46, 1), (51, 31), (58, 1), (67, 1), (78, 1),
  ];

  static Future<List<Surah>> load() async {
    final c = _cache;
    if (c != null) return c;
    final raw = jsonDecode(await rootBundle.loadString('assets/quran/quran.json')) as Map<String, dynamic>;
    final list = <Surah>[
      for (final s in raw['s'] as List)
        Surah((s['n'] as num).toInt(), s['name'] as String, s['meccan'] as bool,
            [for (final a in s['a'] as List) a as String])
    ];
    return _cache = list;
  }

  /// إزالة التشكيل وتوحيد الألف لتسهيل البحث.
  static String norm(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      final inMarks = (r >= 0x0610 && r <= 0x061A) ||
          (r >= 0x064B && r <= 0x065F) ||
          r == 0x0670 ||
          (r >= 0x06D6 && r <= 0x06ED) ||
          (r >= 0x08D3 && r <= 0x08FF) ||
          r == 0x0640;
      if (inMarks) continue;
      if (r == 0x0671 || r == 0x0622 || r == 0x0623 || r == 0x0625) {
        b.writeCharCode(0x0627);
      } else if (r == 0x0649) {
        b.writeCharCode(0x064A);
      } else if (r == 0x0629) {
        b.writeCharCode(0x0647);
      } else {
        b.writeCharCode(r);
      }
    }
    return b.toString();
  }

  /// بحث في نص الآيات (بدون تشكيل). يعيد (السورة، رقم الآية).
  static Future<List<(Surah, int)>> search(String q, {int limit = 100}) async {
    final all = await load();
    _normCache ??= [for (final s in all) [for (final a in s.ayahs) norm(a)]];
    final nq = norm(q.trim());
    if (nq.length < 2) return [];
    final out = <(Surah, int)>[];
    for (var i = 0; i < all.length; i++) {
      final n = _normCache![i];
      for (var j = 0; j < n.length; j++) {
        if (n[j].contains(nq)) {
          out.add((all[i], j + 1));
          if (out.length >= limit) return out;
        }
      }
    }
    return out;
  }

  static const _kLast = 'quran_last';
  static const _kFont = 'quran_font';

  static Future<(int, int)?> lastRead() async {
    try {
      final v = (await SharedPreferences.getInstance()).getString(_kLast);
      if (v == null) return null;
      final p = v.split(':');
      return (int.parse(p[0]), int.parse(p[1]));
    } catch (_) {
      return null;
    }
  }

  static Future<void> setLastRead(int s, int a) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_kLast, '$s:$a');
    } catch (_) {}
  }

  static Future<double> fontSize() async {
    try {
      return (await SharedPreferences.getInstance()).getDouble(_kFont) ?? 26;
    } catch (_) {
      return 26;
    }
  }

  static Future<void> setFontSize(double v) async {
    try {
      await (await SharedPreferences.getInstance()).setDouble(_kFont, v);
    } catch (_) {}
  }
}
