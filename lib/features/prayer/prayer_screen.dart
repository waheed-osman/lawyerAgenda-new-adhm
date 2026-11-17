import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../core/widgets.dart';
import '../../services/notifications.dart';
import 'prayer_service.dart';

/// مواقيت الصلاة بدون إنترنت، مع تنبيه لكل صلاة وتعديل بالدقائق.
class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});
  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  int _city = 0;
  Map<String, DateTime> _today = {};
  Map<String, DateTime> _tomorrow = {};
  final Map<String, int> _adj = {};
  final Map<String, bool> _on = {};
  bool _ready = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final city = await PrayerService.cityIndex();
    final today = await PrayerService.forDay(now);
    final tomorrow = await PrayerService.forDay(DateTime(now.year, now.month, now.day + 1));
    for (final k in prayerKeys) {
      _adj[k] = await PrayerService.adjust(k);
      _on[k] = await PrayerService.notifyOn(k);
    }
    if (!mounted) return;
    setState(() {
      _city = city;
      _today = today;
      _tomorrow = tomorrow;
      _ready = true;
    });
  }

  Future<void> _changed() async {
    await _load();
    await Notifier.rescheduleAll();
  }

  String _fmt(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'ص' : 'م'}';
  }

  /// الصلاة التالية (بما فيها فجر الغد بعد العشاء). الشروق لا يُحسب صلاة.
  (String, DateTime) _next() {
    final now = DateTime.now();
    for (final k in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      if (_today[k]!.isAfter(now)) return (k, _today[k]!);
    }
    return ('fajr', _tomorrow['fajr']!);
  }

  String _remain(DateTime t) {
    final m = t.difference(DateTime.now()).inMinutes;
    final h = m ~/ 60;
    final mm = m % 60;
    if (h == 0) return '$mm دقيقة';
    return mm == 0 ? '$h ساعة' : '$h ساعة و$mm دقيقة';
  }

  Future<void> _adjustDialog(String k) async {
    var v = _adj[k] ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('ضبط وقت ${prayerLabels[k]}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('لمطابقة التقويم الرسمي: زِد أو انقص دقائق من الوقت المحسوب.'),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton.filledTonal(onPressed: () => setS(() => v = (v - 1).clamp(-30, 30).toInt()), icon: const Icon(Icons.remove)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(v == 0 ? '0' : (v > 0 ? '+$v' : '$v'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              IconButton.filledTonal(onPressed: () => setS(() => v = (v + 1).clamp(-30, 30).toInt()), icon: const Icon(Icons.add)),
            ]),
            const Text('دقيقة'),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await PrayerService.setAdjust(k, v);
      await _changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!_ready) {
      return Scaffold(appBar: AppBar(title: const Text('مواقيت الصلاة')), body: const Center(child: CircularProgressIndicator()));
    }
    final (nk, nt) = _next();
    return Scaffold(
      appBar: AppBar(title: const Text('مواقيت الصلاة')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(
          color: cs.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text('الصلاة القادمة', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text('${prayerLabels[nk]} ${_fmt(nt)}',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              Text('بعد ${_remain(nt)}'),
              const SizedBox(height: 4),
              Text(fmtDate(DateTime.now()), style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _city,
          decoration: const InputDecoration(labelText: 'المدينة', prefixIcon: Icon(Icons.location_city)),
          items: [
            for (var i = 0; i < egyptCities.length; i++) DropdownMenuItem(value: i, child: Text(egyptCities[i].name)),
          ],
          onChanged: (v) async {
            if (v == null) return;
            await PrayerService.setCity(v);
            await _changed();
          },
        ),
        const SizedBox(height: 8),
        for (final k in prayerKeys)
          Card(
            color: k == nk ? cs.secondaryContainer.withOpacity(0.6) : null,
            child: ListTile(
              leading: Icon(k == 'sunrise' ? Icons.wb_twilight : Icons.access_time,
                  color: k == nk ? cs.primary : null),
              title: Text(prayerLabels[k]!, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: (_adj[k] ?? 0) == 0 ? null : Text('ضبط يدوي ${_adj[k]! > 0 ? '+' : ''}${_adj[k]} دقيقة'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_fmt(_today[k]!), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  tooltip: 'ضبط بالدقائق',
                  icon: const Icon(Icons.tune),
                  onPressed: () => _adjustDialog(k),
                ),
                if (k != 'sunrise')
                  Switch(
                    value: _on[k] ?? false,
                    onChanged: (v) async {
                      await PrayerService.setNotify(k, v);
                      await _changed();
                    },
                  ),
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'تُحسب المواقيت داخل التطبيق بدون إنترنت بطريقة الهيئة المصرية العامة للمساحة (الفجر 19.5° والعشاء 17.5°) '
            'وتتبع توقيت جهازك الصيفي/الشتوي تلقائيًا. قد تختلف دقيقة أو دقيقتين عن التقويم الرسمي لمدينتك، '
            'فاضبطها بالدقائق من أيقونة الضبط. المفتاح بجانب كل صلاة يُفعّل التنبيه عند دخول وقتها.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ]),
    );
  }
}
