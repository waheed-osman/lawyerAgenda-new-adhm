import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// درجات القيد وصيغة التعريف المناسبة لكل درجة.
const lawyerDegrees = <String, String>{
  'تحت التمرين': 'المحامي تحت التمرين',
  'ابتدائي': 'المحامي المقبول أمام المحاكم الابتدائية',
  'استئناف': 'المحامي بالاستئناف العالي ومجلس الدولة',
  'نقض': 'المحامي بالنقض والإدارية العليا والدستورية العليا',
};

/// بيانات المحامي (تُحفظ على الجهاز وتُضمَّن في النسخة الاحتياطية) وتُستخدم تلقائيًا
/// في نموذج الإنابة والتقارير ورسائل الموكلين.
class LawyerProfile {
  String name, regNo, degree, syndicate, phone, email, office;
  LawyerProfile({
    this.name = '',
    this.regNo = '',
    this.degree = '',
    this.syndicate = '',
    this.phone = '',
    this.email = '',
    this.office = '',
  });

  static const _key = 'lawyer_profile';

  /// نسخة في الذاكرة للاستخدام المتزامن (التقارير). تُحمَّل عند بدء التطبيق وتُحدَّث عند الحفظ.
  static LawyerProfile current = LawyerProfile();

  bool get isFilled => name.trim().isNotEmpty;

  /// مثال: "المحامي بالنقض والإدارية العليا والدستورية العليا".
  String get degreePhrase => lawyerDegrees[degree] ?? 'المحامي';

  /// مثال: "قيد رقم 1234 - نقابة محامين شمال القاهرة".
  String get regLine {
    final p = <String>[
      if (regNo.trim().isNotEmpty) 'قيد رقم ${regNo.trim()}',
      if (syndicate.trim().isNotEmpty) syndicate.trim(),
    ];
    return p.join(' - ');
  }

  /// سطر توقيع للتقارير والرسائل.
  String get signatureLine {
    if (!isFilled) return '';
    final p = <String>[
      'الأستاذ/ ${name.trim()}',
      degreePhrase,
      if (regLine.isNotEmpty) regLine,
      if (phone.trim().isNotEmpty) 'هاتف ${phone.trim()}',
    ];
    return p.join(' • ');
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'regNo': regNo,
        'degree': degree,
        'syndicate': syndicate,
        'phone': phone,
        'email': email,
        'office': office,
      };

  factory LawyerProfile.fromMap(Map m) => LawyerProfile(
        name: '${m['name'] ?? ''}',
        regNo: '${m['regNo'] ?? ''}',
        degree: '${m['degree'] ?? ''}',
        syndicate: '${m['syndicate'] ?? ''}',
        phone: '${m['phone'] ?? ''}',
        email: '${m['email'] ?? ''}',
        office: '${m['office'] ?? ''}',
      );

  static Future<LawyerProfile> load() async {
    try {
      final s = (await SharedPreferences.getInstance()).getString(_key);
      if (s != null) current = LawyerProfile.fromMap(jsonDecode(s) as Map);
    } catch (_) {}
    return current;
  }

  Future<void> save() async {
    current = this;
    try {
      await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(toMap()));
    } catch (_) {}
  }

  /// للنسخة الاحتياطية.
  static Map<String, dynamic> exportMap() => current.toMap();

  static Future<void> importMap(Object? m) async {
    if (m is Map) await LawyerProfile.fromMap(m).save();
  }
}
