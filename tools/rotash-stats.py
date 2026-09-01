#!/usr/bin/env python3
"""Firestore に入っているグループ状態を読んで、Phase 0 の指標を出す。

アプリのコードには一切触らない。読み取り専用。

  python3 tools/rotash-stats.py            # 集計を表示
  python3 tools/rotash-stats.py --csv out  # out-groups.csv / out-weeks.csv も書き出す

接続情報は環境変数 ROTASH_PROJECT_ID / ROTASH_API_KEY / ROTASH_COLLECTION、
未設定なら Rotash/Services/Sync/SyncConfig.swift から読む
（どちらもクライアントに配る前提の値で、秘密鍵ではない）。

出せるのは docs/GROWTH_DIAGNOSIS.md の補助指標のうち3つ:
  - 3人到達率   … members の人数分布
  - 完成率      … 週ごとの充填数
  - R 週次継続率 … archive の積み上がり方
K（作品あたり新規グループ数）は招待リンクの originGroupID が要るので、
N2 が入ってグループが動き出してから出る。
"""

from __future__ import annotations

import argparse
import collections
import csv
import datetime as dt
import json
import os
import re
import sys
import urllib.parse
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SYNC_CONFIG = os.path.join(REPO, "Rotash", "Services", "Sync", "SyncConfig.swift")


# ── 接続情報 ────────────────────────────────────────────────────────────

def _from_swift(name: str) -> str:
    """SyncConfig.swift の `static let <name> = "..."` を1つ読む。"""
    try:
        with open(SYNC_CONFIG, encoding="utf-8") as handle:
            source = handle.read()
    except OSError:
        return ""
    found = re.search(r'static\s+let\s+%s\s*=\s*"([^"]*)"' % re.escape(name), source)
    return found.group(1) if found else ""


def config() -> tuple[str, str, str]:
    project = os.environ.get("ROTASH_PROJECT_ID") or _from_swift("firebaseProjectID")
    key = os.environ.get("ROTASH_API_KEY") or _from_swift("firebaseAPIKey")
    collection = os.environ.get("ROTASH_COLLECTION") or _from_swift("collection") or "rotash"
    if not project or not key:
        sys.exit(
            "接続情報が見つかりません。ROTASH_PROJECT_ID と ROTASH_API_KEY を設定するか、\n"
            f"{SYNC_CONFIG} を埋めてください。"
        )
    return project, key, collection


# ── 取得 ────────────────────────────────────────────────────────────────

def fetch_documents(project: str, key: str, collection: str) -> list[dict]:
    """コレクションを全ページ舐めて、payload を parse したものを返す。"""
    base = (
        f"https://firestore.googleapis.com/v1/projects/{project}"
        f"/databases/(default)/documents/{collection}"
    )
    groups: list[dict] = []
    token = None

    while True:
        query = {"pageSize": "300", "key": key}
        if token:
            query["pageToken"] = token
        with urllib.request.urlopen(f"{base}?{urllib.parse.urlencode(query)}") as response:
            page = json.load(response)

        for document in page.get("documents", []):
            fields = document.get("fields", {})
            payload = fields.get("payload", {}).get("stringValue")
            if not payload:
                continue
            try:
                state = json.loads(payload)
            except json.JSONDecodeError:
                continue
            state["_docID"] = document["name"].rsplit("/", 1)[-1]
            state["_updatedAt"] = fields.get("updatedAt", {}).get("timestampValue")
            groups.append(state)

        token = page.get("nextPageToken")
        if not token:
            break

    return groups


# ── 集計 ────────────────────────────────────────────────────────────────

def parse_time(value):
    if not value:
        return None
    try:
        return dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None


def week_rows(group: dict) -> list[dict]:
    """currentWeek + archive を1行ずつに開く。"""
    rows = []
    weeks = [(group.get("currentWeek"), True)] + [(w, False) for w in group.get("archive") or []]
    for week, is_current in weeks:
        if not week:
            continue
        slots = week.get("slots") or []
        filled = [s for s in slots if s.get("photoFilename") or s.get("photoURL")]
        rows.append(
            {
                "group": group.get("name") or "-",
                "code": group.get("_docID", "-"),
                "start": str(week.get("startDate", ""))[:10],
                "slots": len(slots),
                "filled": len(filled),
                "title": week.get("title") or "",
                "current": is_current,
                "shot_hours": [
                    t.hour
                    for t in (parse_time(s.get("capturedAt")) for s in filled)
                    if t is not None
                ],
            }
        )
    return rows


def bar(count: int, total: int, width: int = 28) -> str:
    if total <= 0:
        return ""
    return "█" * max(0, round(width * count / total))


def report(groups: list[dict]) -> None:
    if not groups:
        print("グループが1つも見つかりませんでした。")
        return

    sizes = [len(g.get("members") or []) for g in groups]
    total = len(groups)

    print(f"\n{'=' * 62}\n  グループ数  {total}\n{'=' * 62}\n")

    # ── 3人到達率 ──
    print("■ メンバー数の分布  ← 3人到達率（最大の詰まり）")
    counter = collections.Counter(sizes)
    for size in range(0, max(sizes) + 1):
        n = counter.get(size, 0)
        if n == 0 and size > 7:
            continue
        mark = "  ← 体験が成立しない" if size < 3 else ""
        print(f"   {size}人 {n:>4}  {bar(n, total)}{mark}")
    reached = sum(1 for s in sizes if s >= 3)
    print(f"\n   3人以上に到達: {reached} / {total}  = {reached / total:.0%}   （目標 60%以上）\n")

    # ── 完成率 ──
    weeks = [row for group in groups for row in week_rows(group)]
    finished = [w for w in weeks if not w["current"]]
    print("■ 週ごとの充填数  ← 完成率")
    if finished:
        full = sum(1 for w in finished if w["filled"] == w["slots"])
        near = sum(1 for w in finished if w["slots"] and w["filled"] >= w["slots"] / 2)
        print(f"   終了した週: {len(finished)}")
        print(f"   全枠そろった週:      {full} / {len(finished)} = {full / len(finished):.0%}")
        print(f"   半分以上そろった週:  {near} / {len(finished)} = {near / len(finished):.0%}   （目標 70%以上）")
        dist = collections.Counter(w["filled"] for w in finished)
        for n in sorted(dist):
            print(f"     {n}枚 {dist[n]:>4}  {bar(dist[n], len(finished))}")
    else:
        print("   まだ終了した週がありません。")
    print()

    # ── R（週次継続率） ──
    print("■ 続いた週数  ← R（週次継続率）")
    lengths = [1 + len(g.get("archive") or []) for g in groups]
    dist = collections.Counter(lengths)
    for n in sorted(dist):
        print(f"   {n}週目 {dist[n]:>4}  {bar(dist[n], total)}")
    two_plus = sum(1 for n in lengths if n >= 2)
    print(f"\n   2週目に到達: {two_plus} / {total} = {two_plus / total:.0%}")
    print("   ※ 1週目は手で口説いた直後なので高くて当然。見るべきはここ。\n")

    # ── 撮影時刻 ──
    hours = [h for w in weeks for h in w["shot_hours"]]
    print("■ 撮影された時刻  ← 通知を何時に出すべきか")
    if hours:
        by_hour = collections.Counter(hours)
        peak = max(by_hour, key=lambda h: by_hour[h])
        for h in range(24):
            n = by_hour.get(h, 0)
            if n:
                print(f"   {h:02d}時 {n:>4}  {bar(n, len(hours))}")
        print(f"\n   最も多い時刻: {peak:02d}時台（{len(hours)} 枚）\n")
    else:
        print("   撮影された写真がまだありません。\n")

    # ── タイトル ──
    titled = [w["title"] for w in weeks if w["title"]]
    print(f"■ 週のタイトル  {len(titled)} 件")
    for t in titled[:10]:
        print(f"   「{t}」")
    print()

    # ── K ──
    origins = [g.get("originGroupID") for g in groups if g.get("originGroupID")]
    print("■ K（作品あたり新規グループ数）")
    if origins:
        by_parent = collections.Counter(origins)
        print(f"   招待リンク経由で生まれたグループ: {len(origins)} / {total}")
        print(f"   親グループ数: {len(by_parent)}   K = {len(origins) / len(by_parent):.2f}")
    else:
        print("   originGroupID を持つグループがまだありません。")
        print("   （N2 の招待リンクが入って、そこから作られたグループが出てから測れます）")
    print()


def write_csv(groups: list[dict], prefix: str) -> None:
    with open(f"{prefix}-groups.csv", "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["code", "name", "members", "weeks", "originGroupID", "updatedAt"])
        for g in groups:
            writer.writerow([
                g.get("_docID", ""),
                g.get("name", ""),
                len(g.get("members") or []),
                1 + len(g.get("archive") or []),
                g.get("originGroupID") or "",
                g.get("_updatedAt") or "",
            ])

    with open(f"{prefix}-weeks.csv", "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["code", "group", "start", "slots", "filled", "current", "title"])
        for group in groups:
            for row in week_rows(group):
                writer.writerow([
                    row["code"], row["group"], row["start"],
                    row["slots"], row["filled"], row["current"], row["title"],
                ])

    print(f"書き出しました: {prefix}-groups.csv / {prefix}-weeks.csv")


def main() -> None:
    parser = argparse.ArgumentParser(description="Rotash の Firestore を集計する（読み取り専用）")
    parser.add_argument("--csv", metavar="PREFIX", help="CSV も書き出す")
    args = parser.parse_args()

    project, key, collection = config()
    print(f"取得中: {project}/{collection} …")
    groups = fetch_documents(project, key, collection)
    report(groups)
    if args.csv:
        write_csv(groups, args.csv)


if __name__ == "__main__":
    main()
