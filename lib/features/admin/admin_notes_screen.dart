import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../core/widgets.dart';
import '../../data/db.dart';
import 'admin_note_editor_screen.dart';
import 'admin_notes_repo.dart';

/// مفكرة الأعمال الإدارية: ورقة حرة تكتب فيها أي عمل إداري، مع مرفقات وتنبيه.
class AdminNotesScreen extends StatefulWidget {
  const AdminNotesScreen({super.key});
  @override
  State<AdminNotesScreen> createState() => _AdminNotesScreenState();
}

class _AdminNotesScreenState extends State<AdminNotesScreen> {
  final _quick = TextEditingController();
  bool _showDone = false;

  Future<void> _add() async {
    final t = _quick.text.trim();
    if (t.isEmpty) return;
    _quick.clear();
    await AdminNotesRepo.save(AdminNote(title: t));
  }

  Future<void> _open(AdminNote? n) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => AdminNoteEditorScreen(note: n)));

  String _when(DateTime d) =>
      '${fmtShort(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Widget _card(BuildContext c, AdminNote n) {
    final cs = Theme.of(c).colorScheme;
    final imgs = n.files.where((f) => f.isImage).take(3).toList();
    return Dismissible(
      key: ValueKey('note${n.id}'),
      background: Container(
        color: cs.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline),
      ),
      secondaryBackground: Container(
        color: cs.errorContainer,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline),
      ),
      confirmDismiss: (_) => confirm(c, 'حذف هذه الملاحظة ومرفقاتها؟', ok: 'حذف'),
      onDismissed: (_) => AdminNotesRepo.delete(n),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          onTap: () => _open(n),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 12, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Checkbox(value: n.done, onChanged: (v) => AdminNotesRepo.setDone(n, v ?? false)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 8),
                  Text(
                    n.title.isEmpty ? (n.body.isEmpty ? 'ملاحظة' : n.body) : n.title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: n.done ? TextDecoration.lineThrough : null,
                        color: n.done ? Theme.of(c).hintColor : null),
                  ),
                  if (n.title.isNotEmpty && n.body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(n.body, maxLines: 3, overflow: TextOverflow.ellipsis),
                    ),
                  if (n.remindAt != null || n.files.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(spacing: 6, runSpacing: 4, children: [
                        if (n.remindAt != null)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: Icon(Icons.alarm, size: 16, color: n.overdue ? cs.error : null),
                            label: Text(_when(n.remindAt!),
                                style: TextStyle(color: n.overdue ? cs.error : null, fontSize: 12)),
                          ),
                        if (n.files.isNotEmpty)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.attach_file, size: 16),
                            label: Text('${n.files.length}', style: const TextStyle(fontSize: 12)),
                          ),
                      ]),
                    ),
                  if (imgs.isNotEmpty && !kIsWeb)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(children: [
                        for (final f in imgs)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(AppFiles.resolve(f.file).path),
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  cacheWidth: 160,
                                  errorBuilder: (_, __, ___) =>
                                      Container(width: 56, height: 56, color: Colors.black12)),
                            ),
                          ),
                      ]),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مفكرة الأعمال الإدارية')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(null),
        icon: const Icon(Icons.edit_note),
        label: const Text('ملاحظة تفصيلية'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            controller: _quick,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              hintText: 'اكتب عملًا إداريًا واضغط إدخال...',
              prefixIcon: const Icon(Icons.add_task),
              suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: _add),
            ),
          ),
        ),
        Expanded(
          child: Live<List<AdminNote>>(
            load: AdminNotesRepo.list,
            builder: (c, all) {
              final open = all.where((n) => !n.done).toList();
              final done = all.where((n) => n.done).toList();
              if (all.isEmpty) {
                return const EmptyState(
                    icon: Icons.sticky_note_2_outlined,
                    text: 'مفكرتك فاضية. اكتب أول عمل إداري فوق، أو اضغط "ملاحظة تفصيلية" لإضافة صورة أو تنبيه.');
              }
              return ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 96), children: [
                for (final n in open) _card(c, n),
                if (done.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showDone = !_showDone),
                      icon: Icon(_showDone ? Icons.expand_less : Icons.expand_more),
                      label: Text('المنجز (${done.length})'),
                    ),
                  ),
                if (_showDone) for (final n in done) _card(c, n),
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('اسحب الملاحظة يمينًا أو يسارًا للحذف. علّم المربع عند إنجازها.',
                      style: TextStyle(fontSize: 12)),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
