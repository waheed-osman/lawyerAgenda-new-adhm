import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/utils.dart';
import 'quran_data.dart';

/// قراءة سورة آية بآية. الضغط على الآية يحفظ علامة "آخر قراءة"، والضغط المطوّل ينسخها.
class SurahReaderScreen extends StatefulWidget {
  final Surah surah;
  final int startAyah;
  const SurahReaderScreen({super.key, required this.surah, this.startAyah = 1});
  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  double _font = 26;
  int _mark = 0;

  @override
  void initState() {
    super.initState();
    QuranData.fontSize().then((v) {
      if (mounted) setState(() => _font = v);
    });
    QuranData.lastRead().then((v) {
      if (v != null && v.$1 == widget.surah.n && mounted) setState(() => _mark = v.$2);
    });
  }

  String _num(int n) {
    const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => d[int.parse(c)]).join();
  }

  void _setFont(double v) {
    setState(() => _font = v.clamp(18, 44).toDouble());
    QuranData.setFontSize(_font);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.surah;
    final cs = Theme.of(context).colorScheme;
    final showBasm = s.n != 1 && s.n != 9;
    return Scaffold(
      appBar: AppBar(title: Text('سورة ${s.name}'), actions: [
        IconButton(tooltip: 'تصغير الخط', icon: const Icon(Icons.text_decrease), onPressed: () => _setFont(_font - 2)),
        IconButton(tooltip: 'تكبير الخط', icon: const Icon(Icons.text_increase), onPressed: () => _setFont(_font + 2)),
      ]),
      body: ScrollablePositionedList.builder(
        initialScrollIndex: widget.startAyah.clamp(0, s.ayahs.length).toInt(),
        itemCount: s.ayahs.length + 1,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 40),
        itemBuilder: (c, i) {
          if (i == 0) {
            return Column(children: [
              Card(
                color: cs.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Center(
                    child: Text('سورة ${s.name} • ${s.typeLabel} • ${s.ayahs.length} آية',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
              if (showBasm)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: _font, height: 1.8)),
                ),
            ]);
          }
          final a = i;
          final marked = _mark == a;
          return InkWell(
            onTap: () async {
              await QuranData.setLastRead(s.n, a);
              if (!mounted) return;
              setState(() => _mark = a);
              toast(context, 'تم حفظ علامة القراءة عند الآية $a');
            },
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: '${s.ayahs[a - 1]} (${s.name}: $a)'));
              toast(context, 'تم نسخ الآية');
            },
            child: Container(
              color: marked ? cs.secondaryContainer.withOpacity(0.5) : null,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: s.ayahs[a - 1]),
                  TextSpan(text: ' ۝${_num(a)} ', style: TextStyle(color: cs.primary)),
                ]),
                textAlign: TextAlign.justify,
                style: TextStyle(fontSize: _font, height: 2.0),
              ),
            ),
          );
        },
      ),
    );
  }
}
