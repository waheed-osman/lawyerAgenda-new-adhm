import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../screens/ai_screen.dart';
import '../../screens/appointment_form_screen.dart';
import '../../screens/case_form_screen.dart';
import '../../screens/client_form_screen.dart';
import '../admin/admin_note_editor_screen.dart';
import '../guide/guide_screen.dart';
import '../obligations/obligation_form_screen.dart';

/// إعداد إظهار الأزرار العائمة (يُحفظ على الجهاز).
class QuickFab {
  static final ValueNotifier<bool> enabled = ValueNotifier(true);
  static const _k = 'quick_fab';

  static Future<void> load() async {
    try {
      enabled.value = (await SharedPreferences.getInstance()).getBool(_k) ?? true;
    } catch (_) {}
  }

  static Future<void> set(bool v) async {
    enabled.value = v;
    try {
      await (await SharedPreferences.getInstance()).setBool(_k, v);
    } catch (_) {}
  }
}

/// أزرار عائمة على حافة الشاشة في كل التبويبات: "إضافة سريعة" و"المساعد الذكي" و"دليل الاستخدام".
class QuickActionsOverlay extends StatelessWidget {
  final Widget child;
  const QuickActionsOverlay({super.key, required this.child});

  void _go(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

  void _addSheet(BuildContext context) {
    Widget item(IconData i, String t, Widget Function() page) => ListTile(
          leading: Icon(i),
          title: Text(t),
          onTap: () {
            Navigator.pop(context);
            _go(context, page());
          },
        );
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          item(Icons.gavel, 'قضية جديدة', () => const CaseFormScreen()),
          item(Icons.person_add_alt_1, 'موكل جديد', () => const ClientFormScreen()),
          item(Icons.event_available, 'موعد جديد', () => const AppointmentFormScreen()),
          item(Icons.sticky_note_2_outlined, 'ملاحظة / عمل إداري', () => const AdminNoteEditorScreen()),
          item(Icons.account_balance_wallet_outlined, 'التزام شخصي', () => const ObligationFormScreen()),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: QuickFab.enabled,
      builder: (c, on, _) => Stack(children: [
        child,
        if (on)
          PositionedDirectional(
            start: 6,
            bottom: 150,
            child: Opacity(
              opacity: 0.92,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                FloatingActionButton.small(
                  heroTag: 'qf_help',
                  tooltip: 'دليل الاستخدام',
                  onPressed: () => _go(c, const GuideScreen()),
                  child: const Icon(Icons.help_outline),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'qf_ai',
                  tooltip: 'المساعد الذكي',
                  onPressed: () => _go(c, const AiScreen()),
                  child: const Icon(Icons.auto_awesome),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'qf_add',
                  tooltip: 'إضافة سريعة',
                  onPressed: () => _addSheet(c),
                  child: const Icon(Icons.add),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}
