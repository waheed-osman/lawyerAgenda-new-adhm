import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/backup.dart';
import '../../data/db.dart';

enum SyncResult { notConfigured, upToDate, pushed, pulled, conflict, error }

class SyncConfig {
  String owner, repo, token, passphrase;
  bool auto;
  SyncConfig({this.owner = '', this.repo = '', this.token = '', this.passphrase = '', this.auto = false});
  bool get ready => owner.isNotEmpty && repo.isNotEmpty && token.isNotEmpty && passphrase.isNotEmpty;
}

/// مزامنة مشفّرة بين الأجهزة (الويب والأندرويد) عبر مستودع GitHub خاص.
/// التشفير AES-256-GCM يتم على الجهاز بكلمة سر لا تغادره، فلا يرى GitHub إلا بيانات مشفرة.
class SyncService with WidgetsBindingObserver {
  SyncService._();
  static final SyncService i = SyncService._();

  static const _path = 'lawyer_agenda_sync.json';
  static const _branch = 'main';

  final cfg = SyncConfig();
  final ValueNotifier<String> status = ValueNotifier('غير مفعّلة');
  final ValueNotifier<DateTime?> lastSync = ValueNotifier(null);

  String _deviceId = '';
  String _lastSha = '';
  bool _dirty = false;
  bool _busy = false;
  bool _muteChanges = false;
  Timer? _debounce;
  Timer? _poll;
  final _aes = AesGcm.with256bits();
  final _keyCache = <String, SecretKey>{};

  SharedPreferences? _sp;

  Future<void> init() async {
    try {
      final sp = _sp = await SharedPreferences.getInstance();
      cfg
        ..owner = sp.getString('sync_owner') ?? ''
        ..repo = sp.getString('sync_repo') ?? ''
        ..token = sp.getString('sync_token') ?? ''
        ..passphrase = sp.getString('sync_pass') ?? ''
        ..auto = sp.getBool('sync_auto') ?? false;
      _lastSha = sp.getString('sync_sha') ?? '';
      _dirty = sp.getBool('sync_dirty') ?? false;
      var id = sp.getString('sync_device');
      if (id == null || id.isEmpty) {
        id = List.generate(8, (_) => Random.secure().nextInt(16).toRadixString(16)).join();
        await sp.setString('sync_device', id);
      }
      _deviceId = id;
      final ls = sp.getInt('sync_last');
      if (ls != null) lastSync.value = DateTime.fromMillisecondsSinceEpoch(ls);
    } catch (_) {}
    status.value = cfg.ready ? 'جاهزة' : 'غير مفعّلة';
    Db.i.addListener(_onDbChanged);
    WidgetsBinding.instance.addObserver(this);
    if (cfg.ready && cfg.auto) unawaited(syncNow());
    // فحص دوري كل دقيقتين لالتقاط تغييرات الجهاز الآخر دون إعادة فتح التطبيق
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(minutes: 2), (_) {
      if (cfg.ready && cfg.auto) unawaited(syncNow());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && cfg.ready && cfg.auto) unawaited(syncNow());
  }

  void _onDbChanged() {
    if (_muteChanges || !cfg.ready) return;
    _setDirty(true);
    if (cfg.auto) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 25), () => syncNow());
    }
  }

  Future<void> _setDirty(bool v) async {
    _dirty = v;
    try {
      await _sp?.setBool('sync_dirty', v);
    } catch (_) {}
  }

  Future<void> saveConfig() async {
    final sp = _sp ??= await SharedPreferences.getInstance();
    await sp.setString('sync_owner', cfg.owner);
    await sp.setString('sync_repo', cfg.repo);
    await sp.setString('sync_token', cfg.token);
    await sp.setString('sync_pass', cfg.passphrase);
    await sp.setBool('sync_auto', cfg.auto);
    status.value = cfg.ready ? 'جاهزة' : 'غير مفعّلة';
  }

  Future<void> disconnect() async {
    cfg
      ..owner = ''
      ..repo = ''
      ..token = ''
      ..passphrase = ''
      ..auto = false;
    _lastSha = '';
    _dirty = false;
    final sp = _sp ??= await SharedPreferences.getInstance();
    for (final k in ['sync_owner', 'sync_repo', 'sync_token', 'sync_pass', 'sync_sha', 'sync_dirty', 'sync_last']) {
      await sp.remove(k);
    }
    await sp.setBool('sync_auto', false);
    lastSync.value = null;
    status.value = 'غير مفعّلة';
  }

  // ---------- GitHub ----------
  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${cfg.token}',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  Uri get _url => Uri.https('api.github.com', '/repos/${cfg.owner}/${cfg.repo}/contents/$_path', {'ref': _branch});

  /// يعيد sha للملف أو null إن لم يوجد بعد. يرمي استثناء برسالة عربية عند الخطأ.
  Future<String?> _remoteSha() async {
    final r = await http.get(_url, headers: _headers).timeout(const Duration(seconds: 40));
    if (r.statusCode == 404) {
      // 404 قد يعني مستودعًا غير موجود أو توكن غير صالح؛ نتحقق من المستودع.
      final rr = await http
          .get(Uri.https('api.github.com', '/repos/${cfg.owner}/${cfg.repo}'), headers: _headers)
          .timeout(const Duration(seconds: 40));
      if (rr.statusCode == 404) throw 'المستودع غير موجود أو التوكن لا يملك صلاحية عليه';
      if (rr.statusCode == 401) throw 'التوكن غير صالح';
      return null;
    }
    if (r.statusCode == 401) throw 'التوكن غير صالح أو منتهي';
    if (r.statusCode == 403) throw 'ممنوع: راجع صلاحيات التوكن (Contents: Read and write)';
    if (r.statusCode != 200) throw 'خطأ من GitHub (${r.statusCode})';
    final j = jsonDecode(r.body);
    return (j is Map ? j['sha'] : null)?.toString();
  }

  /// يتحقق أن النص هو غلاف التشفير الخاص بنا (وليس ردّ بيانات GitHub الوصفي).
  bool _isEnvelope(String t) {
    try {
      final j = jsonDecode(t);
      return j is Map && j['salt'] is String && j['data'] is String;
    } catch (_) {
      return false;
    }
  }

  /// يستخرج النص من ردّ GitHub الوصفي (content بصيغة base64) إن لم يُرجع المتصفح النص الخام.
  String? _fromMeta(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['content'] is String && (j['content'] as String).trim().isNotEmpty) {
        return utf8.decode(base64Decode((j['content'] as String).replaceAll(RegExp(r'\s'), '')));
      }
    } catch (_) {}
    return null;
  }

  Future<String> _remoteRaw(String sha) async {
    final r = await http
        .get(_url, headers: {..._headers, 'Accept': 'application/vnd.github.raw+json'})
        .timeout(const Duration(minutes: 3));
    if (r.statusCode != 200) throw 'تعذّر تنزيل البيانات (${r.statusCode})';
    final text = utf8.decode(r.bodyBytes);
    if (_isEnvelope(text)) return text;
    // المتصفح قد يتجاهل Accept: نجرّب base64 من الردّ الوصفي
    final m = _fromMeta(text);
    if (m != null && _isEnvelope(m)) return m;
    // الملفات الكبيرة (>1MB): نستخدم Git blobs API
    final b = await http
        .get(Uri.https('api.github.com', '/repos/${cfg.owner}/${cfg.repo}/git/blobs/$sha'), headers: _headers)
        .timeout(const Duration(minutes: 3));
    if (b.statusCode == 200) {
      final m2 = _fromMeta(b.body);
      if (m2 != null && _isEnvelope(m2)) return m2;
    }
    throw 'تعذّر قراءة ملف المزامنة من السحابة (صيغة غير متوقعة)';
  }

  Future<String> _putRemote(String text, String? sha) async {
    final body = jsonEncode({
      'message': 'sync ${DateTime.now().toIso8601String()}',
      'content': base64Encode(utf8.encode(text)),
      'branch': _branch,
      if (sha != null) 'sha': sha,
    });
    final r = await http
        .put(_url, headers: {..._headers, 'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(minutes: 3));
    if (r.statusCode == 409 || r.statusCode == 422) throw 'تعارض: تغيّرت البيانات على جهاز آخر، أعد المزامنة';
    if (r.statusCode == 401 || r.statusCode == 403) throw 'لا توجد صلاحية كتابة: راجع التوكن';
    if (r.statusCode != 200 && r.statusCode != 201) throw 'تعذّر الرفع (${r.statusCode})';
    final j = jsonDecode(r.body);
    return (j['content']?['sha'] ?? '').toString();
  }

  // ---------- التشفير ----------
  Future<SecretKey> _key(List<int> salt) async {
    final k = base64Encode(salt);
    final c = _keyCache[k];
    if (c != null) return c;
    final key = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256)
        .deriveKeyFromPassword(password: cfg.passphrase, nonce: salt);
    _keyCache[k] = key;
    return key;
  }

  Future<String> _encrypt(String plain) async {
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final key = await _key(salt);
    final box = await _aes.encrypt(utf8.encode(plain), secretKey: key);
    return jsonEncode({
      'v': 1,
      'salt': base64Encode(salt),
      'data': base64Encode(box.concatenation()),
      'updated': DateTime.now().toIso8601String(),
      'device': _deviceId,
      'hasFiles': false,
    });
  }

  /// يفك التشفير ويعيد (النص، هل تحتوي النسخة على ملفات المرفقات).
  Future<(String, bool)> _decrypt(String fileText) async {
    final j = jsonDecode(fileText);
    if (j is! Map || j['salt'] is! String || j['data'] is! String) throw 'ملف المزامنة في السحابة غير صالح';
    final salt = base64Decode(j['salt'] as String);
    final key = await _key(salt);
    try {
      final box = SecretBox.fromConcatenation(base64Decode(j['data'] as String), nonceLength: 12, macLength: 16);
      final plain = await _aes.decrypt(box, secretKey: key);
      return (utf8.decode(plain), j['hasFiles'] == true);
    } catch (_) {
      throw 'كلمة سر التشفير غير صحيحة';
    }
  }

  // ---------- العمليات ----------
  Future<SyncResult> _push(String? sha) async {
    status.value = 'جارٍ الرفع…';
    // البيانات النصية فقط: الملفات الكبيرة تستهلك ذاكرة التليفون وتسبب Out of Memory
    final text = await Backup.exportJson(withFiles: false);
    final enc = await _encrypt(text);
    final newSha = await _putRemote(enc, sha);
    await _markSynced(newSha);
    status.value = 'تم الرفع';
    return SyncResult.pushed;
  }

  Future<SyncResult> _pull(String sha) async {
    status.value = 'جارٍ التنزيل…';
    final String raw;
    try {
      raw = await _remoteRaw(sha);
    } catch (e) {
      throw '[تنزيل] $e';
    }
    final (text, hasFiles) = await _decrypt(raw);
    _muteChanges = true;
    try {
      await Backup.restoreJson(text, keepLocalFiles: !hasFiles);
    } catch (e) {
      throw '[استعادة] $e';
    } finally {
      _muteChanges = false;
    }
    await _markSynced(sha);
    status.value = 'تم التنزيل';
    return SyncResult.pulled;
  }

  Future<void> _markSynced(String sha) async {
    _lastSha = sha;
    await _setDirty(false);
    final now = DateTime.now();
    lastSync.value = now;
    try {
      await _sp?.setString('sync_sha', sha);
      await _sp?.setInt('sync_last', now.millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// مزامنة ذكية: ترفع إن تغيّرت بياناتك فقط، وتنزل إن تغيّرت السحابة فقط،
  /// وعند تغيّر الطرفين تعيد [SyncResult.conflict] ليقرر المستخدم.
  Future<SyncResult> syncNow() async {
    if (!cfg.ready) return SyncResult.notConfigured;
    if (_busy) return SyncResult.upToDate;
    _busy = true;
    try {
      status.value = 'جارٍ الفحص…';
      final remote = await _remoteSha();
      if (remote == null) return await _push(null);
      if (remote == _lastSha) {
        if (_dirty) return await _push(remote);
        status.value = 'محدّثة';
        return SyncResult.upToDate;
      }
      if (_lastSha.isNotEmpty && !_dirty) return await _pull(remote);
      status.value = 'تعارض: البيانات تغيّرت هنا وفي السحابة';
      return SyncResult.conflict;
    } catch (e) {
      status.value = 'خطأ: $e';
      return SyncResult.error;
    } finally {
      _busy = false;
    }
  }

  /// رفع قسري: يستبدل نسخة السحابة ببيانات هذا الجهاز.
  Future<SyncResult> forcePush() async {
    if (!cfg.ready) return SyncResult.notConfigured;
    if (_busy) return SyncResult.upToDate;
    _busy = true;
    try {
      final remote = await _remoteSha();
      return await _push(remote);
    } catch (e) {
      status.value = 'خطأ: $e';
      return SyncResult.error;
    } finally {
      _busy = false;
    }
  }

  /// تنزيل قسري: يستبدل بيانات هذا الجهاز بنسخة السحابة.
  Future<SyncResult> forcePull() async {
    if (!cfg.ready) return SyncResult.notConfigured;
    if (_busy) return SyncResult.upToDate;
    _busy = true;
    try {
      final remote = await _remoteSha();
      if (remote == null) throw 'لا توجد بيانات في السحابة بعد، ارفع من الجهاز الأول';
      return await _pull(remote);
    } catch (e) {
      status.value = 'خطأ: $e';
      return SyncResult.error;
    } finally {
      _busy = false;
    }
  }

  /// اختبار الإعدادات بدون تغيير أي بيانات. يعيد null عند النجاح أو رسالة الخطأ.
  Future<String?> test() async {
    try {
      await _remoteSha();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
