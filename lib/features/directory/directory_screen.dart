import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils.dart';

enum DirType { phone, link }

/// تصنيفات الشاشة (قابلة للتوسعة بإضافة عنصر هنا).
const dirCategories = <String>[
  'الجهات القضائية',
  'منصة مصر الرقمية',
  'نقابة المحامين',
  'الشهر العقاري',
  'محاكم الدقهلية والمنصورة',
  'أرقام طوارئ',
  'أخرى',
];

const _icons = <String, IconData>{
  'gavel': Icons.gavel,
  'court': Icons.account_balance,
  'digital': Icons.language,
  'bar': Icons.badge_outlined,
  'estate': Icons.home_work_outlined,
  'police': Icons.local_police_outlined,
  'ambulance': Icons.emergency_outlined,
  'fire': Icons.local_fire_department_outlined,
  'phone': Icons.phone_outlined,
  'link': Icons.link,
  'city': Icons.location_city_outlined,
};

IconData _iconFor(String k, DirType t) => _icons[k] ?? (t == DirType.phone ? Icons.phone_outlined : Icons.link);

/// عنصر دليل: عنوان + وصف + قيمة اتصال (هاتف أو رابط) + نوع + أيقونة.
class DirItem {
  final String id;
  final String category;
  final String title;
  final String subtitle;
  final String value;
  final DirType type;
  final String icon;
  final bool custom;

  const DirItem({
    required this.id,
    required this.category,
    required this.title,
    this.subtitle = '',
    required this.value,
    required this.type,
    this.icon = '',
    this.custom = false,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'category': category,
        'title': title,
        'subtitle': subtitle,
        'value': value,
        'type': type.name,
        'icon': icon,
      };

  static DirItem? fromJson(Object? o) {
    if (o is! Map) return null;
    final value = (o['value'] ?? '').toString();
    final title = (o['title'] ?? '').toString();
    if (value.isEmpty || title.isEmpty) return null;
    return DirItem(
      id: (o['id'] ?? DateTime.now().microsecondsSinceEpoch).toString(),
      category: (o['category'] ?? 'أخرى').toString(),
      title: title,
      subtitle: (o['subtitle'] ?? '').toString(),
      value: value,
      type: o['type'] == 'phone' ? DirType.phone : DirType.link,
      icon: (o['icon'] ?? '').toString(),
      custom: true,
    );
  }

  Uri? get uri {
    if (type == DirType.phone) {
      final n = value.replaceAll(RegExp(r'[^0-9+]'), '');
      return n.isEmpty ? null : Uri(scheme: 'tel', path: n);
    }
    var u = value.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'https://$u';
    final p = Uri.tryParse(u);
    return (p == null || p.host.isEmpty) ? null : p;
  }
}

/// بيانات مدمجة: روابط رسمية وأرقام طوارئ معروفة فقط. أرقام المحاكم والنقابة الفرعية
/// تختلف وتتغير، فيضيفها المحامي بنفسه بزر (+) لتبقى دقيقة.
const _builtIn = <DirItem>[
  DirItem(id: 'b1', category: 'الجهات القضائية', title: 'وزارة العدل', subtitle: 'الموقع الرسمي وخدمات المحاكم', value: 'https://www.moj.gov.eg', type: DirType.link, icon: 'court'),
  DirItem(id: 'b2', category: 'الجهات القضائية', title: 'محكمة النقض', subtitle: 'الموقع الرسمي، الاستعلام عن الطعون', value: 'https://www.cc.gov.eg', type: DirType.link, icon: 'gavel'),
  DirItem(id: 'b3', category: 'الجهات القضائية', title: 'المحكمة الدستورية العليا', subtitle: 'الموقع الرسمي', value: 'https://www.sccourt.gov.eg', type: DirType.link, icon: 'gavel'),
  DirItem(id: 'b4', category: 'الجهات القضائية', title: 'النيابة العامة', subtitle: 'الموقع الرسمي', value: 'https://www.ppo.gov.eg', type: DirType.link, icon: 'court'),
  DirItem(id: 'b5', category: 'منصة مصر الرقمية', title: 'منصة مصر الرقمية', subtitle: 'الخدمات الحكومية الإلكترونية', value: 'https://digital.gov.eg', type: DirType.link, icon: 'digital'),
  DirItem(id: 'b6', category: 'الشهر العقاري', title: 'خدمات الشهر العقاري', subtitle: 'عبر موقع وزارة العدل (التوكيلات والتوثيق)', value: 'https://www.moj.gov.eg', type: DirType.link, icon: 'estate'),
  DirItem(id: 'b7', category: 'محاكم الدقهلية والمنصورة', title: 'محافظة الدقهلية', subtitle: 'البوابة الرسمية للمحافظة', value: 'https://www.dakahlia.gov.eg', type: DirType.link, icon: 'city'),
  DirItem(id: 'b8', category: 'أرقام طوارئ', title: 'النجدة (الشرطة)', subtitle: 'طوارئ', value: '122', type: DirType.phone, icon: 'police'),
  DirItem(id: 'b9', category: 'أرقام طوارئ', title: 'الإسعاف', subtitle: 'طوارئ', value: '123', type: DirType.phone, icon: 'ambulance'),
  DirItem(id: 'b10', category: 'أرقام طوارئ', title: 'الحماية المدنية (المطافئ)', subtitle: 'طوارئ', value: '180', type: DirType.phone, icon: 'fire'),
];

class DirectoryStore {
  static const _k = 'dir_custom_items';

  static Future<List<DirItem>> loadCustom() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_k);
      if (raw == null || raw.isEmpty) return [];
      final l = jsonDecode(raw);
      if (l is! List) return [];
      return l.map(DirItem.fromJson).whereType<DirItem>().toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCustom(List<DirItem> items) async {
    try {
      await (await SharedPreferences.getInstance())
          .setString(_k, jsonEncode(items.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }
}

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});
  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _search = TextEditingController();
  List<DirItem> _custom = [];
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = await DirectoryStore.loadCustom();
    if (mounted) setState(() => _custom = c);
  }

  Future<void> _act(DirItem i) async {
    final u = i.uri;
    if (u == null) {
      toast(context, i.type == DirType.phone ? 'رقم الهاتف غير صحيح' : 'الرابط غير صحيح');
      return;
    }
    try {
      final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        toast(context, i.type == DirType.phone ? 'تعذّر إجراء الاتصال' : 'تعذّر فتح الرابط');
      }
    } catch (_) {
      if (mounted) toast(context, i.type == DirType.phone ? 'تعذّر إجراء الاتصال' : 'تعذّر فتح الرابط');
    }
  }

  Future<void> _copy(DirItem i) async {
    await Clipboard.setData(ClipboardData(text: i.value));
    if (mounted) toast(context, 'تم النسخ');
  }

  Future<void> _delete(DirItem i) async {
    setState(() => _custom = _custom.where((e) => e.id != i.id).toList());
    await DirectoryStore.saveCustom(_custom);
  }

  Future<void> _add() async {
    final title = TextEditingController();
    final sub = TextEditingController();
    final val = TextEditingController();
    var type = DirType.phone;
    var cat = dirCategories[4];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('إضافة رقم أو رابط'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<DirType>(
                segments: const [
                  ButtonSegment(value: DirType.phone, label: Text('هاتف'), icon: Icon(Icons.phone)),
                  ButtonSegment(value: DirType.link, label: Text('رابط'), icon: Icon(Icons.link)),
                ],
                selected: {type},
                onSelectionChanged: (s) => setS(() => type = s.first),
              ),
              const SizedBox(height: 10),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'الاسم (مثال: محكمة المنصورة الابتدائية)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: sub, decoration: const InputDecoration(labelText: 'وصف مختصر (اختياري)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                controller: val,
                textDirection: TextDirection.ltr,
                keyboardType: type == DirType.phone ? TextInputType.phone : TextInputType.url,
                decoration: InputDecoration(labelText: type == DirType.phone ? 'رقم الهاتف' : 'الرابط', border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: cat,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'التصنيف', border: OutlineInputBorder()),
                items: [for (final c in dirCategories) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setS(() => cat = v ?? cat),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (title.text.trim().isEmpty || val.text.trim().isEmpty) {
      if (mounted) toast(context, 'اكتب الاسم والرقم أو الرابط');
      return;
    }
    final item = DirItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      category: cat,
      title: title.text.trim(),
      subtitle: sub.text.trim(),
      value: val.text.trim(),
      type: type,
      custom: true,
    );
    setState(() => _custom = [..._custom, item]);
    await DirectoryStore.saveCustom(_custom);
  }

  bool _match(DirItem i) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;
    return i.title.toLowerCase().contains(q) ||
        i.subtitle.toLowerCase().contains(q) ||
        i.value.toLowerCase().contains(q) ||
        i.category.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final all = [..._builtIn, ..._custom].where(_match).toList();
    final cats = [
      for (final c in dirCategories)
        if (all.any((e) => e.category == c)) c,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('أرقام وروابط تهم المحامي المصري')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('إضافة'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SearchBar(
            controller: _search,
            hintText: 'ابحث عن محكمة أو جهة أو رقم أو رابط',
            leading: const Icon(Icons.search),
            trailing: [
              if (_q.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _search.clear();
                    setState(() => _q = '');
                  },
                ),
            ],
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(
          child: cats.isEmpty
              ? const Center(child: Text('لا توجد نتائج'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                  children: [
                    Card(
                      color: cs.secondaryContainer,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'اضغط على الرقم للاتصال أو على الرابط لفتحه. اضغط مطولًا للنسخ. أرقام المحاكم والنقابة الفرعية تختلف وتتغير، فأضفها بنفسك بزر «إضافة» وراجع صحتها.',
                          style: TextStyle(height: 1.5, fontSize: 13),
                        ),
                      ),
                    ),
                    for (final c in cats) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                        child: Text(c, style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary, fontSize: 15)),
                      ),
                      for (final i in all.where((e) => e.category == c)) _tile(i, cs),
                    ],
                  ],
                ),
        ),
      ]),
    );
  }

  Widget _tile(DirItem i, ColorScheme cs) {
    final isPhone = i.type == DirType.phone;
    final color = isPhone ? cs.tertiary : cs.primary;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => _act(i),
        onLongPress: () => _copy(i),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(_iconFor(i.icon, i.type), color: color),
        ),
        title: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (i.subtitle.isNotEmpty) Text(i.subtitle, style: const TextStyle(fontSize: 12)),
          Text(i.value, textDirection: TextDirection.ltr, style: TextStyle(fontSize: 12, color: color)),
        ]),
        trailing: i.custom
            ? PopupMenuButton<String>(
                onSelected: (v) => v == 'del' ? _delete(i) : _copy(i),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'copy', child: Text('نسخ')),
                  PopupMenuItem(value: 'del', child: Text('حذف')),
                ],
              )
            : Icon(isPhone ? Icons.call : Icons.open_in_new, color: color),
      ),
    );
  }
}
