# 合并锚点表：我的规则（gen_anchors.py 从 cursor_zh_patch.py 生成，菜单栏+模型页）
# + 早期 v5 规则（设置/用量/远程控制等页，anchors-v5.json）。
# 输出 scripts/anchors.json，供 patch.ps1 使用。合并顺序：我的规则在前。
import json, os, sys

BASE = r"C:\Users\Windows\Doubao\chats\2026-10-29\new-chat\Cursor汉化包\scripts"
MINE = os.path.join(os.environ["TEMP"], "anchors.json")   # gen_anchors.py 的输出
V5 = os.path.join(BASE, "anchors-v5.json")
OUT = os.path.join(BASE, "anchors.json")

mine = json.load(open(MINE, encoding="utf-8"))
v5 = json.load(open(V5, encoding="utf-8"))

merged = {"note": "合并锚点表：玻璃窗(glass)+经典窗(desktop)+用量/积分(xai)。我的规则在前（菜单栏、模型页、API 密钥区），v5 规则在后（设置、用量、远程控制等页）。",
          "targetVersion": "3.27.22"}

for key in ("glass", "desktop"):
    rows = []
    seen = set()
    for r in list(mine.get(key, [])) + list(v5.get(key, [])):
        if r["old"] in seen:
            continue
        seen.add(r["old"])
        rows.append(r)
    merged[key] = rows

merged["xai"] = v5.get("xai", [])

open(OUT, "w", encoding="utf-8", newline="\n").write(
    json.dumps(merged, ensure_ascii=False, indent=2))
print("merged glass:", len(merged["glass"]),
      "desktop:", len(merged["desktop"]),
      "xai:", len(merged["xai"]),
      "bytes:", os.path.getsize(OUT))
