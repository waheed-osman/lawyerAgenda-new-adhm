import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../screens/case_detail_screen.dart';
import '../attention/no_session_screen.dart';
import 'admin_repo.dart';

class _Check {
  final String title, hint;
  final IconData icon;
  final Color color;
  final Future<int> Function() count;
  final Widget Function() page;
  _Check(this.title, this.hint, this.icon, this.color, this.count, this.page);
}

/// الأعمال الإدارية: كشوف سريعة بما يحتاج متابعة في القضايا والجلسات.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final checks = <_Check>[
      _Check('قضايا بدون جلسة قادمة', 'جارية أو مؤجلة ولم يُحدَّد لها موعد', Icons.event_busy,
          const Color(0xFFD84315), () async => (await AdminRepo.noNextSession()).length,
          () => const NoSessionScreen()),
      _Check('جلسات بدون قرار مسجَّل', 'مضى موعدها ولم تُدوَّن نتيجتها', Icons.edit_note,
          const Color(0xFFC62828), () async => (await AdminRepo.sessionsWithoutDecision()).length,
          () => const _SessionsNoDecisionScreen()),
      _Check('قضايا لم يصدر فيها قرار', 'جارية ولا يوجد قرار في أي جلسة منها', Icons.gavel,
          const Color(0xFF6A1B9A), () async => (await AdminRepo.noDecision()).length,
          () => _CasesScreen('قضايا لم يصدر فيها قرار', AdminRepo.noDecision, 'كل القضايا الجارية فيها قرارات')),
      _Check('القضايا الإدارية', 'قضايا نوعها «إداري»', Icons.account_balance,
          const Color(0xFF1565C0), () async => (await AdminRepo.administrative()).length,
          () => _CasesScreen('القضايا الإدارية', AdminRepo.administrative, 'لا توجد قضايا إدارية')),
      _Check('قضايا راكدة', 'لا جلسة قادمة وآخر نشاط قبل أكثر من 90 يومًا', Icons.hourglass_empty,
          const Color(0xFF616161), () async => (await AdminRepo.stale()).length,
          () => _CasesScreen('قضايا راكدة', AdminRepo.stale, 'لا توجد قضايا راكدة')),
      _Check('توكيلات تنتهي قريبًا', 'منتهية أو تنتهي خلال 30 يومًا', Icons.badge_outlined,
          const Color(0xFFEF6C00), () async => (await AdminRepo.poaExpiring()).length,
          () => _CasesScreen('توكيلات تنتهي قريبًا', AdminRepo.poaExpiring, 'لا توجد توكيلات قاربت على الانتهاء',
              showPoa: true)),
      _Check('قضايا ناقصة البيانات', 'بدون موكل أو رقم أو محكمة', Icons.rule,
          const Color(0xFF00796B), () async => (await AdminRepo.incomplete()).length,
          () => _CasesScreen('قضايا ناقصة البيانات', AdminRepo.incomplete, 'كل القضايا مكتملة البيانات')),
      _Check('جاهزة للأرشفة', 'قضايا مكتسبة أو خاسرة لم تُؤرشف', Icons.inventory_2_outlined,
          const Color(0xFF2E7D32), () async => (await AdminRepo.readyToArchive()).length,
          () => _CasesScreen('جاهزة للأرشفة', AdminRepo.readyToArchive, 'لا توجد قضايا جاهزة للأرشفة')),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('الأعمال الإدارية')),
      body: Live<List<int>>(
        load: () async => [for (final c in checks) await c.count()],
        builder: (c, counts) => ListView(padding: const EdgeInsets.all(12), children: [
          for (var i = 0; i < checks.length; i++)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: checks[i].color.withOpacity(0.15),
                  child: Icon(checks[i].icon, color: checks[i].color),
                ),
                title: Text(checks[i].title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(checks[i].hint),
                trailing: CircleAvatar(
                  radius: 16,
                  backgroundColor: counts[i] == 0 ? Colors.green.shade100 : checks[i].color.withOpacity(0.15),
                  child: Text('${counts[i]}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => checks[i].page())),
              ),
            ),
        ]),
      ),
    );
  }
}

/// قائمة قضايا عامة لكشف إداري.
class _CasesScreen extends StatelessWidget {
  final String title, empty;
  final Future<List<LegalCase>> Function() load;
  final bool showPoa;
  const _CasesScreen(this.title, this.load, this.empty, {this.showPoa = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Live<List<LegalCase>>(
        load: load,
        builder: (c, list) => list.isEmpty
            ? EmptyState(icon: Icons.task_alt, text: empty)
            : ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('العدد: ${list.length}', style: Theme.of(c).textTheme.titleSmall),
                ),
                for (final x in list)
                  Column(children: [
                    CaseCard(
                        c: x,
                        onTap: () => Navigator.push(
                            c, MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: x.id!)))),
                    if (showPoa && x.poaExpiry != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('ينتهي التوكيل: ${fmtDate(x.poaExpiry!)} (${relText(x.poaExpiry!)})',
                              style: TextStyle(color: Theme.of(c).colorScheme.error, fontSize: 12)),
                        ),
                      ),
                  ]),
              ]),
      ),
    );
  }
}

class _SessionsNoDecisionScreen extends StatelessWidget {
  const _SessionsNoDecisionScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('جلسات بدون قرار مسجَّل')),
      body: Live<List<CaseSession>>(
        load: AdminRepo.sessionsWithoutDecision,
        builder: (c, list) => list.isEmpty
            ? const EmptyState(icon: Icons.task_alt, text: 'كل الجلسات الماضية فيها قرارات')
            : ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: [
                for (final s in list)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.edit_note),
                      title: Text('${caseLabel(s.caseNumber, s.caseYear)} • ${s.court}'),
                      subtitle: Text('${fmtDate(s.date)} (${relText(s.date)})'
                          '${s.clientName.isEmpty ? '' : '\n${s.clientName}'}'),
                      isThreeLine: s.clientName.isNotEmpty,
                      onTap: () => Navigator.push(
                          c, MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: s.caseId))),
                    ),
                  ),
              ]),
      ),
    );
  }
}
