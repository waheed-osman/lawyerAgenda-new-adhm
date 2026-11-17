import 'package:flutter/material.dart';

import '../../core/utils.dart';
import 'sync_service.dart';

/// شاشة إعداد المزامنة المشفّرة بين الويب والأندرويد.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});
  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _s = SyncService.i;
  late final TextEditingController _owner = TextEditingController(text: _s.cfg.owner);
  late final TextEditingController _repo = TextEditingController(text: _s.cfg.repo);
  late final TextEditingController _token = TextEditingController(text: _s.cfg.token);
  late final TextEditingController _pass = TextEditingController(text: _s.cfg.passphrase);
  bool _busy = false;
  bool _showSecrets = false;

  @override
  void dispose() {
    _owner.dispose();
    _repo.dispose();
    _token.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _s.cfg
      ..owner = _owner.text.trim()
      ..repo = _repo.text.trim()
      ..token = _token.text.trim()
      ..passphrase = _pass.text;
    await _s.saveConfig();
  }

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAndTest() => _run(() async {
        if (_owner.text.trim().isEmpty ||
            _repo.text.trim().isEmpty ||
            _token.text.trim().isEmpty ||
            _pass.text.isEmpty) {
          toast(context, 'املأ كل الخانات الأربع');
          return;
        }
        await _save();
        final err = await _s.test();
        if (!mounted) return;
        toast(context, err == null ? 'الاتصال سليم ✅' : err);
      });

  Future<void> _sync() => _run(() async {
        await _save();
        final r = await _s.syncNow();
        if (!mounted) return;
        await _handle(r);
      });

  Future<void> _handle(SyncResult r) async {
    switch (r) {
      case SyncResult.pushed:
        toast(context, 'تم رفع بياناتك للسحابة المشفّرة');
      case SyncResult.pulled:
        toast(context, 'تم تنزيل آخر بيانات من السحابة');
      case SyncResult.upToDate:
        toast(context, 'كل شيء محدّث');
      case SyncResult.notConfigured:
        toast(context, 'أكمل الإعدادات أولًا');
      case SyncResult.error:
        toast(context, _s.status.value);
      case SyncResult.conflict:
        final c = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تعارض في البيانات'),
            content: const Text(
                'البيانات اتغيّرت على الجهاز ده وعلى جهاز آخر (أو أول مرة تربط هذا الجهاز).\n\n'
                '• «استخدم السحابة»: بيانات هذا الجهاز تتبدّل بنسخة السحابة.\n'
                '• «استخدم هذا الجهاز»: نسخة السحابة تتبدّل ببيانات هذا الجهاز.\n\n'
                'اختر بحذر، والأفضل تاخد نسخة احتياطية أولًا.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              TextButton(onPressed: () => Navigator.pop(ctx, 'pull'), child: const Text('استخدم السحابة')),
              FilledButton(onPressed: () => Navigator.pop(ctx, 'push'), child: const Text('استخدم هذا الجهاز')),
            ],
          ),
        );
        if (c == null || !mounted) return;
        final r2 = c == 'pull' ? await _s.forcePull() : await _s.forcePush();
        if (mounted) await _handle(r2);
    }
  }

  Future<void> _force(bool push) async {
    final ok = await confirm(
      context,
      push
          ? 'نسخة السحابة هتتبدّل ببيانات هذا الجهاز. متأكد؟'
          : 'بيانات هذا الجهاز كلها هتتبدّل بنسخة السحابة. خد نسخة احتياطية الأول. متأكد؟',
    );
    if (!ok) return;
    await _run(() async {
      await _save();
      final r = push ? await _s.forcePush() : await _s.forcePull();
      if (mounted) await _handle(r);
    });
  }

  Future<void> _disconnect() async {
    final ok = await confirm(context, 'هيتم مسح إعدادات المزامنة من هذا الجهاز فقط، وبياناتك والنسخة في السحابة لن تُحذف. متأكد؟');
    if (!ok) return;
    await _s.disconnect();
    _owner.clear();
    _repo.clear();
    _token.clear();
    _pass.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('المزامنة بين الأجهزة')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(
          color: cs.primaryContainer,
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'بياناتك بتتشفّر على جهازك بكلمة سر خاصة بيك (AES-256) قبل ما تترفع لمستودع GitHub خاص بيك. GitHub بيشوف ملف مشفّر ملوش معنى، ومحدش يقدر يقرأه من غير كلمة السر. استخدم نفس الإعدادات على الويب والأندرويد.',
              style: TextStyle(height: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          leading: const Icon(Icons.list_alt),
          title: const Text('خطوات الإعداد (مرة واحدة)'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '١) في GitHub اعمل مستودع جديد **Private** (خاص) اسمه مثلًا lawyer-agenda-data، وحط فيه ملف README.\n'
              '٢) من GitHub: الإعدادات ← Developer settings ← Personal access tokens ← Fine-grained tokens ← Generate new token.\n'
              '٣) اختر المستودع ده بس (Only select repositories)، وفي Permissions اجعل **Contents = Read and write**.\n'
              '٤) انسخ التوكن اللي هيظهر (مرة واحدة بس!) والصقه هنا.\n'
              '٥) اكتب كلمة سر تشفير قوية واحفظها، لو ضاعت مفيش أي طريقة لاسترجاع البيانات المشفّرة.\n'
              '٦) على الجهاز التاني ضع نفس الخانات الأربع بالظبط.',
              style: TextStyle(height: 1.7),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _owner,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'اسم مستخدم GitHub (مثال: waheed-osman)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _repo,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'اسم المستودع الخاص (مثال: lawyer-agenda-data)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _token,
          obscureText: !_showSecrets,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'التوكن (Fine-grained token)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _pass,
          obscureText: !_showSecrets,
          decoration: const InputDecoration(labelText: 'كلمة سر التشفير', border: OutlineInputBorder()),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('إظهار التوكن وكلمة السر'),
          value: _showSecrets,
          onChanged: (v) => setState(() => _showSecrets = v),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _saveAndTest,
          icon: const Icon(Icons.verified_outlined),
          label: const Text('حفظ واختبار الاتصال'),
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<String>(
          valueListenable: _s.status,
          builder: (c, st, _) => ValueListenableBuilder<DateTime?>(
            valueListenable: _s.lastSync,
            builder: (c, ls, _) => Card(
              child: ListTile(
                leading: _busy
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_sync_outlined),
                title: Text('الحالة: $st'),
                subtitle: Text(ls == null ? 'لم تتم مزامنة بعد' : 'آخر مزامنة: ${fmtDate(ls)} ${ls.hour.toString().padLeft(2, '0')}:${ls.minute.toString().padLeft(2, '0')}'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : _sync,
          icon: const Icon(Icons.sync),
          label: const Text('مزامنة الآن'),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('مزامنة تلقائية'),
          subtitle: const Text('عند فتح التطبيق وبعد التعديل بقليل'),
          value: _s.cfg.auto,
          onChanged: (v) async {
            _s.cfg.auto = v;
            await _save();
            if (mounted) setState(() {});
          },
        ),
        const Divider(),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _force(true),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('رفع قسري'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _force(false),
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('تنزيل قسري'),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _busy ? null : _disconnect,
          icon: const Icon(Icons.link_off),
          label: const Text('فصل المزامنة من هذا الجهاز'),
        ),
        const SizedBox(height: 12),
        Text(
          'ملاحظات: المزامنة بتنقل البيانات النصية (الموكلين والقضايا والجلسات والمواعيد والأتعاب...). صور وملفات المرفقات بتفضل على جهازها ولا بتتمسح، وللاحتفاظ بها خد نسخة احتياطية من الإعدادات.',
          style: TextStyle(color: cs.onSurfaceVariant, height: 1.6, fontSize: 12),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}
