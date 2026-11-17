import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../core/widgets.dart';
import 'lawyer_profile.dart';

/// "ملفي": اسم المحامي ورقم القيد والدرجة والنقابة. تظهر تلقائيًا في الإنابة والتقارير.
class LawyerProfileScreen extends StatefulWidget {
  const LawyerProfileScreen({super.key});
  @override
  State<LawyerProfileScreen> createState() => _LawyerProfileScreenState();
}

class _LawyerProfileScreenState extends State<LawyerProfileScreen> {
  final _name = TextEditingController();
  final _reg = TextEditingController();
  final _syn = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _office = TextEditingController();
  String _degree = '';

  @override
  void initState() {
    super.initState();
    final p = LawyerProfile.current;
    _name.text = p.name;
    _reg.text = p.regNo;
    _syn.text = p.syndicate;
    _phone.text = p.phone;
    _email.text = p.email;
    _office.text = p.office;
    _degree = lawyerDegrees.containsKey(p.degree) ? p.degree : '';
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      toast(context, 'اكتب اسم المحامي');
      return;
    }
    await LawyerProfile(
      name: _name.text.trim(),
      regNo: _reg.text.trim(),
      degree: _degree,
      syndicate: _syn.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      office: _office.text.trim(),
    ).save();
    if (!mounted) return;
    toast(context, 'تم حفظ بياناتك');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ملفي (بيانات المحامي)')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('تُستخدم هذه البيانات تلقائيًا في نموذج الإنابة والتقارير ورسائل الموكلين.',
              style: TextStyle(fontSize: 13)),
        ),
        tf(_name, 'اسم المحامي', icon: Icons.person),
        tf(_reg, 'رقم القيد', icon: Icons.badge_outlined),
        DropdownButtonFormField<String>(
          value: _degree.isEmpty ? null : _degree,
          decoration: const InputDecoration(labelText: 'درجة القيد', prefixIcon: Icon(Icons.workspace_premium_outlined)),
          items: [for (final k in lawyerDegrees.keys) DropdownMenuItem(value: k, child: Text(lawyerDegrees[k]!))],
          onChanged: (v) => setState(() => _degree = v ?? ''),
        ),
        const SizedBox(height: 12),
        tf(_syn, 'النقابة الفرعية (اختياري)', icon: Icons.account_balance_outlined),
        tf(_phone, 'رقم الهاتف', icon: Icons.phone, type: TextInputType.phone),
        tf(_email, 'البريد الإلكتروني', icon: Icons.email_outlined, type: TextInputType.emailAddress),
        tf(_office, 'عنوان المكتب', icon: Icons.location_on_outlined, maxLines: 2),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('حفظ')),
      ]),
    );
  }
}
