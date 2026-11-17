import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

/// مفاتيح الصلوات بترتيب اليوم (الشروق ليس صلاة ولا يُنبَّه له).
const prayerKeys = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];

const prayerLabels = <String, String>{
  'fajr': 'الفجر',
  'sunrise': 'الشروق',
  'dhuhr': 'الظهر',
  'asr': 'العصر',
  'maghrib': 'المغرب',
  'isha': 'العشاء',
};

class City {
  final String name;
  final double lat, lon;
  const City(this.name, this.lat, this.lon);
}

/// 27 مدينة مصرية (إحداثيات تقريبية).
const egyptCities = <City>[
  City('القاهرة', 30.0444, 31.2357),
  City('الجيزة', 30.0131, 31.2089),
  City('الإسكندرية', 31.2001, 29.9187),
  City('بورسعيد', 31.2653, 32.3019),
  City('السويس', 29.9668, 32.5498),
  City('الإسماعيلية', 30.5965, 32.2715),
  City('دمياط', 31.4165, 31.8133),
  City('المنصورة', 31.0409, 31.3785),
  City('طنطا', 30.7865, 31.0004),
  City('الزقازيق', 30.5877, 31.5021),
  City('بنها', 30.4660, 31.1848),
  City('شبين الكوم', 30.5503, 31.0121),
  City('دمنهور', 31.0341, 30.4682),
  City('كفر الشيخ', 31.1107, 30.9388),
  City('الفيوم', 29.3084, 30.8428),
  City('بني سويف', 29.0661, 31.0994),
  City('المنيا', 28.1099, 30.7503),
  City('أسيوط', 27.1809, 31.1837),
  City('سوهاج', 26.5591, 31.6948),
  City('قنا', 26.1551, 32.7160),
  City('الأقصر', 25.6872, 32.6396),
  City('أسوان', 24.0889, 32.8998),
  City('الغردقة', 27.2579, 33.8116),
  City('مرسى مطروح', 31.3543, 27.2373),
  City('العريش', 31.1316, 33.7984),
  City('شرم الشيخ', 27.9158, 34.3300),
  City('الخارجة', 25.4519, 30.5464),
];

/// حساب المواقيت محليًا بدون إنترنت (طريقة الهيئة المصرية العامة للمساحة:
/// الفجر 19.5° والعشاء 17.5° والعصر بظل مثل الشيء).
class PrayerService {
  static const _kCity = 'pray_city';
  static String _kAdj(String k) => 'pray_adj_$k';
  static String _kOn(String k) => 'pray_on_$k';

  static double _rad(double d) => d * math.pi / 180;
  static double _deg(double r) => r * 180 / math.pi;

  static Future<int> cityIndex() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final i = sp.getInt(_kCity) ?? 0;
      return i >= 0 && i < egyptCities.length ? i : 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> setCity(int i) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kCity, i);
  }

  static Future<String> cityName() async => egyptCities[await cityIndex()].name;

  static Future<int> adjust(String k) async {
    try {
      return (await SharedPreferences.getInstance()).getInt(_kAdj(k)) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> setAdjust(String k, int v) async =>
      (await SharedPreferences.getInstance()).setInt(_kAdj(k), v);

  static Future<bool> notifyOn(String k) async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_kOn(k)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setNotify(String k, bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kOn(k), v);

  /// مواقيت يوم [day] لمدينة محددة (بدون ضبط يدوي)، بتوقيت الجهاز المحلي.
  static Map<String, DateTime> compute(City city, DateTime day) {
    final n = DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(day.year, 1, 1)).inDays;
    final g = 2 * math.pi / 365 * n;
    final decl = 0.006918 -
        0.399912 * math.cos(g) +
        0.070257 * math.sin(g) -
        0.006758 * math.cos(2 * g) +
        0.000907 * math.sin(2 * g) -
        0.002697 * math.cos(3 * g) +
        0.00148 * math.sin(3 * g);
    final eqt = 229.18 *
        (0.000075 +
            0.001868 * math.cos(g) -
            0.032077 * math.sin(g) -
            0.014615 * math.cos(2 * g) -
            0.040849 * math.sin(2 * g));
    final lat = _rad(city.lat);
    // الزوال بالساعات UTC
    final transit = 12 - city.lon / 15 - eqt / 60;

    // الزاوية الساعية (بالساعات) عند ارتفاع [alt] درجة (سالب = تحت الأفق)
    double ha(double alt) {
      final c = (math.sin(_rad(alt)) - math.sin(lat) * math.sin(decl)) / (math.cos(lat) * math.cos(decl));
      return _deg(math.acos(c.clamp(-1.0, 1.0))) / 15;
    }

    final asrAlt = _deg(math.atan(1 / (1 + math.tan((lat - decl).abs()))));
    final h = <String, double>{
      'fajr': transit - ha(-19.5),
      'sunrise': transit - ha(-0.833),
      'dhuhr': transit + 1 / 60,
      'asr': transit + ha(asrAlt),
      'maghrib': transit + ha(-0.833),
      'isha': transit + ha(-17.5),
    };
    final base = DateTime.utc(day.year, day.month, day.day);
    return {
      for (final e in h.entries) e.key: base.add(Duration(seconds: (e.value * 3600).round())).toLocal(),
    };
  }

  /// مواقيت يوم [day] لمدينة المستخدم مع الضبط اليدوي بالدقائق.
  static Future<Map<String, DateTime>> forDay(DateTime day) async {
    final city = egyptCities[await cityIndex()];
    final m = compute(city, day);
    final out = <String, DateTime>{};
    for (final k in prayerKeys) {
      out[k] = m[k]!.add(Duration(minutes: await adjust(k)));
    }
    return out;
  }

  /// تنبيهات الصلوات المفعّلة خلال [days] يومًا قادمًا: (المفتاح، الوقت).
  static Future<List<(String, DateTime)>> upcomingAlerts({int days = 4}) async {
    final now = DateTime.now();
    final on = <String>[
      for (final k in prayerKeys)
        if (k != 'sunrise' && await notifyOn(k)) k
    ];
    final out = <(String, DateTime)>[];
    if (on.isEmpty) return out;
    for (var i = 0; i < days; i++) {
      final m = await forDay(DateTime(now.year, now.month, now.day + i));
      for (final k in on) {
        if (m[k]!.isAfter(now)) out.add((k, m[k]!));
      }
    }
    return out;
  }
}
