#!/usr/bin/env python3
"""تجهيز مشروع الويب أثناء البناء على GitHub Actions (لا يمس نسخة الأندرويد).
1) يستبدل ملفات الويب من web_overrides/ فوق نظيراتها في lib/
2) يضيف حزمة sqflite_common_ffi_web
3) يجهّز ملفات sqlite wasm في مجلد web/
"""
import os, re, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

# 1) استبدال الملفات
MAP = {
    "web_overrides/db_factory.dart": "lib/data/db_factory.dart",
    "web_overrides/web_io.dart": "lib/core/web_io.dart",
}
for src, dst in MAP.items():
    shutil.copyfile(src, dst)
    print("override", dst)

# 2) الحزمة
pub = open("pubspec.yaml", encoding="utf-8").read()
if "sqflite_common_ffi_web" not in pub:
    pub = pub.replace("  sqflite: ", "  sqflite_common_ffi_web: ^0.4.5+3\n  sqflite: ", 1)
    open("pubspec.yaml", "w", encoding="utf-8").write(pub)
    print("added sqflite_common_ffi_web")

# 3) ملفات wasm
subprocess.check_call(["flutter", "pub", "get"])
subprocess.check_call(["dart", "run", "sqflite_common_ffi_web:setup", "--force"])

# index.html: اتجاه عربي وعنوان
idx = os.path.join("web", "index.html")
if os.path.exists(idx):
    s = open(idx, encoding="utf-8").read()
    s = s.replace("<html>", '<html lang="ar" dir="rtl">', 1)
    s = re.sub(r"<title>.*?</title>", "<title>أجندة المحامي القانونية</title>", s, count=1)
    open(idx, "w", encoding="utf-8").write(s)
print("web setup done")
