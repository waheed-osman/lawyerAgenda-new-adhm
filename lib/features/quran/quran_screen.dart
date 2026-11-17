import 'package:flutter/material.dart';

import 'quran_data.dart';
import 'surah_reader_screen.dart';

/// المصحف: السور، الأجزاء، البحث، وعلامة آخر قراءة. النص بالرسم العثماني من Tanzil.net (CC BY 3.0).
class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});
  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  List<Surah>? _surahs;
  (int, int)? _last;
  final _q = TextEditingController();
  List<(Surah, int)> _hits = [];
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final s = await QuranData.load();
    final l = await QuranData.lastRead();
    if (mounted) {
      setState(() {
        _surahs = s;
        _last = l;
      });
    }
  }

  Future<void> _open(Surah s, [int ayah = 1]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SurahReaderScreen(surah: s, startAyah: ayah)));
    final l = await QuranData.lastRead();
    if (mounted) setState(() => _last = l);
  }

  Future<void> _search(String v) async {
    final r = await QuranData.search(v);
    if (mounted) {
      setState(() {
        _hits = r;
        _searched = v.trim().length >= 2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _surahs;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('القرآن الكريم'),
          bottom: const TabBar(tabs: [Tab(text: 'السور'), Tab(text: 'الأجزاء'), Tab(text: 'بحث')]),
        ),
        body: all == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [
                ListView(padding: const EdgeInsets.all(8), children: [
                  if (_last != null)
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.bookmark),
                        title: Text('متابعة القراءة: سورة ${all[_last!.$1 - 1].name} الآية ${_last!.$2}'),
                        onTap: () => _open(all[_last!.$1 - 1], _last!.$2),
                      ),
                    ),
                  for (final s in all)
                    ListTile(
                      leading: CircleAvatar(radius: 16, child: Text('${s.n}', style: const TextStyle(fontSize: 12))),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${s.typeLabel} • ${s.ayahs.length} آية'),
                      onTap: () => _open(s),
                    ),
                ]),
                ListView(padding: const EdgeInsets.all(8), children: [
                  for (var i = 0; i < QuranData.juzStarts.length; i++)
                    ListTile(
                      leading: CircleAvatar(radius: 16, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                      title: Text('الجزء ${i + 1}'),
                      subtitle: Text(
                          'يبدأ من سورة ${all[QuranData.juzStarts[i].$1 - 1].name} الآية ${QuranData.juzStarts[i].$2}'),
                      onTap: () => _open(all[QuranData.juzStarts[i].$1 - 1], QuranData.juzStarts[i].$2),
                    ),
                ]),
                Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _q,
                      decoration: const InputDecoration(
                          hintText: 'ابحث في الآيات (بدون تشكيل)...', prefixIcon: Icon(Icons.search)),
                      onChanged: _search,
                    ),
                  ),
                  Expanded(
                    child: !_searched
                        ? const Center(child: Text('اكتب كلمتين على الأقل'))
                        : _hits.isEmpty
                            ? const Center(child: Text('لا توجد نتائج'))
                            : ListView(children: [
                                for (final h in _hits)
                                  ListTile(
                                    title: Text(h.$1.ayahs[h.$2 - 1], maxLines: 2, overflow: TextOverflow.ellipsis),
                                    subtitle: Text('سورة ${h.$1.name} • آية ${h.$2}'),
                                    onTap: () => _open(h.$1, h.$2),
                                  ),
                              ]),
                  ),
                ]),
              ]),
      ),
    );
  }
}
