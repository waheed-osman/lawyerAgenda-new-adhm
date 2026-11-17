import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../data/db.dart';
import '../../data/models.dart';

class _Rule {
  final String title, basis, kind;
  final int days;
  const _Rule(this.title, this.days, this.basis, this.kind);
}

const _groups = <String, List<_Rule>>{
  'مدني / تجاري / أسرة': [
    _Rule('استئناف', 40, 'م 227 مرافعات — من صدور الحكم (أو من الإعلان في الحالات المنصوص عليها م 213)', 'appeal'),
    _Rule('استئناف في المواد المستعجلة', 15, 'م 227 مرافعات', 'appeal'),
    _Rule('نقض', 60, 'م 252 مرافعات', 'cassation'),
    _Rule('التماس إعادة النظر', 40, 'م 242 مرافعات', 'appeal'),
  ],
  'جنح ومخالفات': [
    _Rule('استئناف حكم جنحة', 10, 'م 406 إجراءات جنائية — من النطق بالحكم الحضوري أو من إعلان الغيابي', 'appeal'),
    _Rule('معارضة في حكم غيابي', 10, 'من تاريخ إعلان الحكم الغيابي', 'opposition'),
    _Rule('نقض جنائي', 60, 'قانون 57 لسنة 1959 م 34', 'cassation'),
  ],
};

class DeadlineScreen extends StatefulWidget {
  const DeadlineScreen({super.key});
  @override
  State<DeadlineScreen> createState() => _DeadlineScreenState();
}

class _DeadlineScreenState extends State<DeadlineScreen> {
  String group = _groups.keys.first;
  late _Rule rule = _groups[group]!.first;
  DateTime start = dayStart(DateTime.now());
  LegalCase? lcase;

  // يوم صدور الحكم لا يُحتسب، فالميعاد ينتهي بعد (المدة) يوم من اليوم التالي.
  DateTime get end => start.add(Duration(days: rule.days));
  int get left => end.difference(dayStart(DateTime.now())).inDays;
  bool get weekend => end.weekday == DateTime.friday || end.weekday == DateTime.saturday;

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('ar'),
    );
    if (d != null) setState(() => start = dayStart(d));
  }

  Future<void> _pickCase() async {
    final list = await Db.i.cases(archived: false);
    if (!mounted) return;
    final c = await showModalBottomSheet<LegalCase>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(children: [
          for (final x in list)
            ListTile(
              title: Text(caseLabel(x.number, x.year)),
              subtitle: Text(x.clientName),
              onTap: () => Navigator.pop(context, x),
            ),
        ]),
      ),
    );
    if (c != null) setState(() => lcase = c);
  }

  Future<void> _save() async {
    final label = lcase == null ? '' : caseLabel(lcase!.number, lcase!.year);
    final a = Appointment(
      title: 'آخر ميعاد ${rule.title}${label.isEmpty ? '' : ' — $label'}',
      notes: 'محسوب من ${fmtShort(start)} (${rule.days} يوم). ${rule.basis}. راجع الحساب قبل الاعتماد عليه.',
      date: end,
      caseId: lcase?.id,
      caseLabelText: label,
      kind: rule.kind,
    );
    await Db.i.saveAppointment(a);
    if (!mounted) return;
    toast(context, 'اتضاف في المواعيد، وهيجيلك تنبيه قبلها بـ 7 و 3 أيام');
  }

  @override
  Widget build(BuildContext context) {
    final overdue = left < 0;
    final color = overdue ? Colors.red : (left <= 7 ? Colors.orange : Colors.green);
    return Scaffold(
      appBar: AppBar(title: const Text('حاسبة مواعيد الطعن')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(
          value: group,
          decoration: const InputDecoration(labelText: 'نوع القضية', border: OutlineInputBorder()),
          items: [for (final g in _groups.keys) DropdownMenuItem(value: g, child: Text(g))],
          onChanged: (v) => setState(() {
            group = v!;
            rule = _groups[group]!.first;
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<_Rule>(
          value: rule,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'نوع الطعن', border: OutlineInputBorder()),
          items: [
            for (final r in _groups[group]!) DropdownMenuItem(value: r, child: Text('${r.title} (${r.days} يوم)')),
          ],
          onChanged: (v) => setState(() => rule = v!),
        ),
        const SizedBox(height: 12),
        ListTile(
          shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
          leading: const Icon(Icons.event),
          title: const Text('تاريخ بداية الميعاد (النطق بالحكم أو الإعلان)'),
          subtitle: Text(fmtDate(start)),
          onTap: _pickDate,
        ),
        const SizedBox(height: 8),
        ListTile(
          shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
          leading: const Icon(Icons.folder_open),
          title: Text(lcase == null ? 'ربط بقضية (اختياري)' : caseLabel(lcase!.number, lcase!.year)),
          trailing: lcase == null ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => lcase = null)),
          onTap: _pickCase,
        ),
        const SizedBox(height: 16),
        Card(
          color: color.withOpacity(0.12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Text('آخر يوم للطعن'),
              const SizedBox(height: 6),
              Text(fmtDate(end), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(overdue ? 'الميعاد فات من ${-left} يوم' : (left == 0 ? 'آخر يوم النهارده!' : 'فاضل $left يوم'),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
              if (weekend) ...[
                const SizedBox(height: 8),
                const Text('الميعاد بيقع في إجازة أسبوعية؛ لو إجازة رسمية بيتمد لأول يوم عمل، لكن الأحوط تقدّم قبلها.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text('الأساس: ${rule.basis}\nيوم صدور الحكم مش بيتحسب. الفوات = سقوط الحق في الطعن.',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: overdue ? null : _save,
          icon: const Icon(Icons.add_alert),
          label: const Text('إضافة للمواعيد مع تنبيه'),
        ),
        const SizedBox(height: 12),
        const Text('تنبيه: الحاسبة للمساعدة فقط. راجع النص القانوني الحالي ومواعيد المسافة وحالات الانقطاع (وفاة/فقد أهلية) قبل الاعتماد على التاريخ.',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    );
  }
}
