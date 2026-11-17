#!/usr/bin/env python3
"""يبني assets/quran/quran.json من نص Tanzil (الرسم العثماني) — نسخ حرفي بدون تعديل.
المصدر: Tanzil.net (CC BY 3.0). يُشغَّل يدويًا على جهاز المطوّر فقط؛ الملف الناتج مرفق في المشروع.
usage: build_quran_asset.py <tanzil/uthmani.json> <tanzil/chapters.json> <out.json>
"""
import json, sys
u = json.load(open(sys.argv[1], encoding="utf-8"))
ch = json.load(open(sys.argv[2], encoding="utf-8"))["chapters"]
BASM = u["1"][0]["text"]  # البسملة كما وردت في الفاتحة
out = []
for c in ch:
    v = [x["text"] for x in u[str(c["id"])]]
    assert len(v) == c["total_verses"], c["id"]
    # نص Tanzil يلصق البسملة بأول آية في كل سورة عدا الفاتحة والتوبة؛ نفصلها لتُعرض كترويسة.
    if c["id"] not in (1, 9) and v[0].startswith(BASM + " "):
        v[0] = v[0][len(BASM) + 1:]
    out.append({"n": c["id"], "name": c["name"], "meccan": c["type"] == "meccan", "a": v})
assert sum(len(s["a"]) for s in out) == 6236
json.dump({"s": out}, open(sys.argv[3], "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print("ok", len(out), "surahs")
