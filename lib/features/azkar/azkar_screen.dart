import 'package:flutter/material.dart';

import 'azkar_data.dart';

/// قائمة مجموعات الأذكار.
class AzkarScreen extends StatelessWidget {
  const AzkarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأذكار')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        for (final g in azkarGroups)
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text(g.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${g.items.length} ذكر'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ZikrGroupScreen(group: g))),
            ),
          ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('اضغط على الذكر لينقص العدّاد. راجع النصوص قبل الاعتماد عليها.',
              style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}

class ZikrGroupScreen extends StatefulWidget {
  final ZikrGroup group;
  const ZikrGroupScreen({super.key, required this.group});
  @override
  State<ZikrGroupScreen> createState() => _ZikrGroupScreenState();
}

class _ZikrGroupScreenState extends State<ZikrGroupScreen> {
  late List<int> _left = [for (final z in widget.group.items) z.count];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = widget.group.items;
    return Scaffold(
      appBar: AppBar(title: Text(widget.group.title), actions: [
        IconButton(
          tooltip: 'إعادة العدّاد',
          icon: const Icon(Icons.restart_alt),
          onPressed: () => setState(() => _left = [for (final z in items) z.count]),
        ),
      ]),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (c, i) {
          final z = items[i];
          final done = _left[i] == 0;
          return Card(
            color: done ? cs.primaryContainer.withOpacity(0.5) : null,
            child: InkWell(
              onTap: done ? null : () => setState(() => _left[i]--),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(z.text, style: const TextStyle(fontSize: 20, height: 1.9)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Text(z.source, style: Theme.of(c).textTheme.bodySmall)),
                    done
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : CircleAvatar(radius: 18, child: Text('${_left[i]}')),
                  ]),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
