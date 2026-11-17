import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils.dart';
import '../../core/widgets.dart';
import '../../data/db.dart';
import '../../services/security.dart';
import 'admin_notes_repo.dart';

/// محرّر ملاحظة: عنوان + تفاصيل + وقت تذكير + مرفقات (صور تذاكر ومستندات). يحفظ تلقائيًا عند الرجوع.
class AdminNoteEditorScreen extends StatefulWidget {
  final AdminNote? note;
  const AdminNoteEditorScreen({super.key, this.note});
  @override
  State<AdminNoteEditorScreen> createState() => _AdminNoteEditorScreenState();
}

class _AdminNoteEditorScreenState extends State<AdminNoteEditorScreen> {
  late final AdminNote _n = widget.note ?? AdminNote();
  late final _title = TextEditingController(text: _n.title);
  late final _body = TextEditingController(text: _n.body);

  void _sync() {
    _n.title = _title.text;
    _n.body = _body.text;
  }

  bool get _empty => _title.text.trim().isEmpty && _body.text.trim().isEmpty && _n.files.isEmpty;

  /// يحفظ الملاحظة (وينشئها عند أول مرفق). الملاحظة الفارغة الجديدة لا تُحفظ.
  Future<void> _save({bool force = false}) async {
    _sync();
    if (_n.id == null && _empty && !force) return;
    if (_n.id == null && _n.title.trim().isEmpty && _n.body.trim().isEmpty) _n.title = 'عمل إداري';
    await AdminNotesRepo.save(_n);
  }

  Future<void> _pickRemind() async {
    final now = DateTime.now();
    final base = _n.remindAt ?? now.add(const Duration(hours: 1));
    final d = await pickDate(context, base);
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (t == null) return;
    setState(() => _n.remindAt = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _attach(String kind) async {
    await _save(force: true);
    final paths = <(String, String)>[];
    await Security.guard(() async {
      if (kind == 'camera') {
        final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
        if (x != null) paths.add((x.path, x.name));
      } else if (kind == 'gallery') {
        final xs = await ImagePicker().pickMultiImage(imageQuality: 85);
        for (final x in xs) {
          paths.add((x.path, x.name));
        }
      } else {
        final r = await FilePicker.platform.pickFiles(allowMultiple: true);
        for (final f in r?.files ?? const <PlatformFile>[]) {
          if (f.path != null) paths.add((f.path!, f.name));
        }
      }
    });
    for (final p in paths) {
      final f = await AdminNotesRepo.addFile(_n.id!, p.$1, p.$2);
      _n.files.add(f);
    }
    if (mounted) setState(() {});
  }

  void _attachMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('تصوير تذكرة / ورقة'),
            onTap: () {
              Navigator.pop(ctx);
              _attach('camera');
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('صورة من المعرض'),
            onTap: () {
              Navigator.pop(ctx);
              _attach('gallery');
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('مستند (PDF / Word / ...)'),
            onTap: () {
              Navigator.pop(ctx);
              _attach('file');
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _openFile(AdminFile f) async {
    if (f.isImage) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewScreen(file: f.file)));
    } else {
      await Security.guard(() => Share.shareXFiles([XFile(AppFiles.resolve(f.file).path)], subject: f.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _save();
        if (context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.note == null ? 'ملاحظة جديدة' : 'ملاحظة'),
          actions: [
            if (_n.id != null)
              IconButton(
                tooltip: 'حذف',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirm(context, 'حذف هذه الملاحظة ومرفقاتها؟', ok: 'حذف')) {
                    await AdminNotesRepo.delete(_n);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            IconButton(
              tooltip: 'حفظ',
              icon: const Icon(Icons.check),
              onPressed: () async {
                await _save();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(
            controller: _title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(hintText: 'العنوان (مثال: استخراج صورة حكم - محكمة ...)', border: InputBorder.none),
          ),
          TextField(
            controller: _body,
            minLines: 6,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(hintText: 'اكتب هنا بحرية...', border: InputBorder.none),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.alarm, color: _n.overdue ? cs.error : null),
            title: Text(_n.remindAt == null
                ? 'إضافة تنبيه'
                : '${fmtDate(_n.remindAt!)} - ${_n.remindAt!.hour.toString().padLeft(2, '0')}:${_n.remindAt!.minute.toString().padLeft(2, '0')}'),
            trailing: _n.remindAt == null
                ? null
                : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _n.remindAt = null)),
            onTap: _pickRemind,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _n.done,
            onChanged: (v) => setState(() => _n.done = v ?? false),
            title: const Text('تم الإنجاز'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const Divider(),
          Row(children: [
            Expanded(child: Text('المرفقات (${_n.files.length})', style: Theme.of(context).textTheme.titleSmall)),
            if (!kIsWeb)
              OutlinedButton.icon(
                onPressed: _attachMenu,
                icon: const Icon(Icons.attach_file),
                label: const Text('إضافة صورة / مستند'),
              ),
          ]),
          const SizedBox(height: 8),
          if (_n.files.isEmpty)
            const Padding(padding: EdgeInsets.all(8), child: Text('لا توجد مرفقات'))
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final f in _n.files)
                GestureDetector(
                  onTap: () => _openFile(f),
                  onLongPress: () async {
                    if (await confirm(context, 'حذف هذا المرفق؟', ok: 'حذف')) {
                      await AdminNotesRepo.deleteFile(f);
                      if (mounted) setState(() => _n.files.remove(f));
                    }
                  },
                  child: f.isImage && !kIsWeb
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(File(AppFiles.resolve(f.file).path),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              cacheWidth: 300,
                              errorBuilder: (_, __, ___) =>
                                  Container(width: 100, height: 100, color: Colors.black12, child: const Icon(Icons.broken_image))),
                        )
                      : Container(
                          width: 100,
                          height: 100,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.insert_drive_file_outlined),
                            const SizedBox(height: 4),
                            Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                          ]),
                        ),
                ),
            ]),
          if (_n.files.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('اضغط للعرض/الفتح، واضغط مطولًا للحذف', style: TextStyle(fontSize: 12)),
            ),
        ]),
      ),
    );
  }
}
