import '../../data/db.dart';

/// ملف مرفق بملاحظة (صورة تذكرة أو مستند).
class AdminFile {
  final int? id;
  final int noteId;
  final String file; // اسم الملف داخل مجلد التطبيق
  final String name; // الاسم الأصلي للعرض
  AdminFile({this.id, required this.noteId, required this.file, required this.name});

  static const _img = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic', '.bmp'];
  bool get isImage => _img.any((e) => file.toLowerCase().endsWith(e));
}

/// ملاحظة في مفكرة الأعمال الإدارية.
class AdminNote {
  int? id;
  String title, body;
  DateTime? remindAt;
  bool done;
  DateTime createdAt;
  List<AdminFile> files;
  AdminNote({
    this.id,
    this.title = '',
    this.body = '',
    this.remindAt,
    this.done = false,
    DateTime? createdAt,
    List<AdminFile>? files,
  })  : createdAt = createdAt ?? DateTime.now(),
        files = files ?? [];

  bool get overdue => !done && remindAt != null && remindAt!.isBefore(DateTime.now());
}

class AdminNotesRepo {
  static DateTime? _dt(Object? v) => v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);

  /// كل الملاحظات (غير المنجزة أولًا، الأحدث فالأقدم) مع مرفقاتها.
  static Future<List<AdminNote>> list() async {
    final d = await Db.i.db;
    final rows = await d.query('admin_notes', orderBy: 'done ASC, COALESCE(updated_at, created_at) DESC');
    final files = await d.query('admin_files', orderBy: 'id ASC');
    final byNote = <int, List<AdminFile>>{};
    for (final f in files) {
      final nid = f['note_id'] as int?;
      if (nid == null) continue;
      byNote.putIfAbsent(nid, () => []).add(AdminFile(
          id: f['id'] as int?, noteId: nid, file: '${f['file'] ?? ''}', name: '${f['name'] ?? ''}'));
    }
    return [
      for (final r in rows)
        AdminNote(
          id: r['id'] as int?,
          title: '${r['title'] ?? ''}',
          body: '${r['body'] ?? ''}',
          remindAt: _dt(r['remind_at']),
          done: (r['done'] as int? ?? 0) == 1,
          createdAt: _dt(r['created_at']) ?? DateTime.now(),
          files: byNote[r['id'] as int] ?? [],
        )
    ];
  }

  static Future<int> save(AdminNote n) async {
    final d = await Db.i.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final m = <String, Object?>{
      'title': n.title.trim(),
      'body': n.body.trim(),
      'remind_at': n.remindAt?.millisecondsSinceEpoch,
      'done': n.done ? 1 : 0,
      'updated_at': now,
    };
    if (n.id == null) {
      m['created_at'] = n.createdAt.millisecondsSinceEpoch;
      n.id = await d.insert('admin_notes', m);
    } else {
      await d.update('admin_notes', m, where: 'id=?', whereArgs: [n.id]);
    }
    Db.i.changed();
    return n.id!;
  }

  static Future<void> setDone(AdminNote n, bool v) async {
    n.done = v;
    await save(n);
  }

  /// يحذف الملاحظة وملفاتها من الجهاز.
  static Future<void> delete(AdminNote n) async {
    final d = await Db.i.db;
    for (final f in n.files) {
      await AppFiles.deleteFile(f.file);
    }
    await d.delete('admin_files', where: 'note_id=?', whereArgs: [n.id]);
    await d.delete('admin_notes', where: 'id=?', whereArgs: [n.id]);
    Db.i.changed();
  }

  static Future<AdminFile> addFile(int noteId, String sourcePath, String name) async {
    final d = await Db.i.db;
    final stored = await AppFiles.saveCopy(sourcePath);
    final id = await d.insert('admin_files', {
      'note_id': noteId,
      'file': stored,
      'name': name,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    Db.i.changed();
    return AdminFile(id: id, noteId: noteId, file: stored, name: name);
  }

  static Future<void> deleteFile(AdminFile f) async {
    final d = await Db.i.db;
    await AppFiles.deleteFile(f.file);
    await d.delete('admin_files', where: 'id=?', whereArgs: [f.id]);
    Db.i.changed();
  }
}
