import '../../core/utils.dart';
import '../../data/db.dart';
import '../../data/models.dart';

/// كشوف الأعمال الإدارية: استعلامات على بيانات القضايا والجلسات الموجودة (بدون جداول جديدة).
class AdminRepo {
  static bool _open(LegalCase c) => c.status == 'active' || c.status == 'postponed';

  /// قضايا جارية/مؤجلة بلا جلسة قادمة.
  static Future<List<LegalCase>> noNextSession() => Db.i.casesWithoutNextSession();

  /// قضايا إدارية (نوعها «إداري») غير مؤرشفة.
  static Future<List<LegalCase>> administrative() async =>
      (await Db.i.cases(archived: false, type: 'إداري'));

  /// قضايا جارية لم يُسجَّل قرار في أي من جلساتها بعد.
  static Future<List<LegalCase>> noDecision() async {
    final d = await Db.i.db;
    final r = await d.rawQuery("SELECT DISTINCT case_id FROM sessions WHERE TRIM(IFNULL(decision,''))<>''");
    final withDecision = {for (final e in r) (e['case_id'] as num).toInt()};
    final all = await Db.i.cases(archived: false);
    return all.where((c) => _open(c) && !withDecision.contains(c.id)).toList();
  }

  /// جلسات مضت ولم يُسجَّل فيها قرار (لقضايا جارية).
  static Future<List<CaseSession>> sessionsWithoutDecision() async {
    final now = DateTime.now();
    final list = await Db.i.sessions(overdueNoDecision: true, desc: true);
    return list.where((s) => s.date.isBefore(dayStart(now))).toList();
  }

  /// قضايا ناقصة بيانات أساسية (بدون موكل أو رقم أو محكمة).
  static Future<List<LegalCase>> incomplete() async {
    final all = await Db.i.cases(archived: false);
    return all
        .where((c) => c.clientId == null || c.number.trim().isEmpty || c.court.trim().isEmpty)
        .toList();
  }

  /// توكيلات انتهت أو تنتهي خلال 30 يومًا.
  static Future<List<LegalCase>> poaExpiring() async {
    final limit = dayStart(DateTime.now()).add(const Duration(days: 30));
    final all = await Db.i.cases(archived: false);
    final l = all.where((c) => c.poaExpiry != null && c.poaExpiry!.isBefore(limit)).toList()
      ..sort((a, b) => a.poaExpiry!.compareTo(b.poaExpiry!));
    return l;
  }

  /// قضايا راكدة: جارية، آخر جلسة لها قبل أكثر من 90 يومًا ولا جلسة قادمة.
  static Future<List<LegalCase>> stale() async {
    final d = await Db.i.db;
    final r = await d.rawQuery('SELECT case_id, MAX(date) AS m FROM sessions GROUP BY case_id');
    final last = {for (final e in r) (e['case_id'] as num).toInt(): (e['m'] as num).toInt()};
    final cut = DateTime.now().subtract(const Duration(days: 90)).millisecondsSinceEpoch;
    final all = await Db.i.cases(archived: false);
    return all.where((c) {
      if (!_open(c) || c.nextDate != null) return false;
      final m = last[c.id];
      return m == null ? c.createdAt < cut : m < cut;
    }).toList();
  }

  /// قضايا مكتسبة/خاسرة وغير مؤرشفة (جاهزة للأرشفة).
  static Future<List<LegalCase>> readyToArchive() async {
    final all = await Db.i.cases(archived: false);
    return all.where((c) => c.status == 'won' || c.status == 'lost').toList();
  }
}
