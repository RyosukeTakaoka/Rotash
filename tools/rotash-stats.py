#!/usr/bin/env python3
"""Firestore に入っているグループ状態を読んで、Phase 0 の指標を出す。

アプリのコードには一切触らない。読み取り専用。

  python3 tools/rotash-stats.py            # 集計を表示
  python3 tools/rotash-stats.py --csv out  # out-groups.csv / out-weeks.csv も書き出す
  python3 tools/rotash-stats.py --from-file docs.json   # Firestore の代わりに手元の JSON を読む

接続情報は環境変数 ROTASH_PROJECT_ID / ROTASH_API_KEY / ROTASH_COLLECTION、
未設定なら Rotash/Services/Sync/SyncConfig.swift から読む
（どちらもクライアントに配る前提の値で、秘密鍵ではない）。

出せるのは docs/GROWTH_DIAGNOSIS.md の補助指標のうち3つ:
  - 3人到達率   … いま参加中（leftAt が無い）メンバーの人数分布
  - 完成率      … 終わった週ごとの充填数。週はカレンダーから数える
  - R 週次継続率 … カレンダー上の N 週目に1枚でも撮られたか

週を archive から数えないのは、0枚で終わった週はアプリが archive に残さないから
（AppViewModel の週送りと RotashMerge.consolidate がどちらも filledCount > 0 で絞る）。
archive だけを見ると「誰も撮らなかった週」が分母から消え、完成率も継続率も実際より高く出る。
そこで、グループの最初の週（archive + currentWeek の startDate のうち一番古いもの）から
今日を含む週までを7日刻みで並べ、archive に無い週は「0枚の週」として扱う。
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

def parse_documents(page: dict) -> list[dict]:
    """Firestore REST の1ページ分から、payload を parse したグループ状態を取り出す。"""
    groups: list[dict] = []
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
    return groups


def load_file(path: str) -> list[dict]:
    """手元の JSON から読む（検証用・オフライン集計用）。

    受け付ける形は2つ:
      - Firestore REST の一覧レスポンスそのもの（{"documents": [...]}）。またはそのページの配列
      - payload を parse 済みのグループ状態の配列（RemoteGroupState の JSON をそのまま並べたもの）
    """
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    pages = data if isinstance(data, list) else [data]
    groups: list[dict] = []
    for index, item in enumerate(pages):
        if isinstance(item, dict) and "documents" in item:
            groups.extend(parse_documents(item))
        elif isinstance(item, dict):
            state = dict(item)
            state.setdefault("_docID", state.get("inviteCode") or state.get("id") or f"#{index}")
            state.setdefault("_updatedAt", None)
            groups.append(state)
    return groups


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

        groups.extend(parse_documents(page))

        token = page.get("nextPageToken")
        if not token:
            break

    return groups


# ── 集計 ────────────────────────────────────────────────────────────────

def parse_time(value):
    if not value:
        return None
    try:
        parsed = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
    # 週の並べ替えで「今日」（UTC）と引き算するので、時差の無い値は UTC とみなしてそろえる。
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=dt.timezone.utc)


WEEK = dt.timedelta(days=7)


def active_members(group: dict) -> list[dict]:
    """いま参加中のメンバー。

    抜けた人は members から消さずに leftAt を付けるだけなので（Member.leftAt）、
    len(members) は「延べ参加人数」であって、いまのグループの人数ではない。
    当番が回るのも leftAt の無い人だけ（RotashGroup.activeMembers）。
    """
    return [m for m in group.get("members") or [] if not m.get("leftAt")]


def _week_row(group: dict, week: dict | None, start: dt.datetime, index: int, now: dt.datetime) -> dict:
    slots = (week or {}).get("slots") or []
    filled = _filled(week or {})
    return {
        "group": group.get("name") or "-",
        "code": group.get("_docID", "-"),
        "start": str(week.get("startDate", ""))[:10] if week else start.isoformat()[:10],
        # 記録が無い週は月曜〜日曜の 7 枚。週途中スタートで枚数が減るのは最初の週だけで、
        # 最初の週は定義上いつも記録がある（そこから数え始めるので）。
        "slots": len(slots) if week else 7,
        "filled": len(filled),
        "title": (week or {}).get("title") or "",
        "number": index + 1,          # カレンダー上の何週目か（1 始まり）
        "stored": week is not None,   # ドキュメントに週が残っていたか（False = 0枚で消えた週）
        # 「今週」かどうかは時計で決める。currentWeek は誰かがアプリを開くまで週送りされないので、
        # 放置されたグループでは currentWeek がとっくに終わった週のまま残っている。
        "current": start + WEEK > now,
        "shot_hours": [
            t.hour
            for t in (parse_time(s.get("capturedAt")) for s in filled)
            if t is not None
        ],
    }


def week_rows(group: dict, now: dt.datetime) -> list[dict]:
    """グループの週を、最初の週から今日を含む週までカレンダー順（古い順）に1行ずつ開く。

    0枚で終わった週は archive に残らないので、ここで「0枚の週」として埋め直す。
    これをしないと、撮られなかった週が完成率・継続率の分母から黙って消える。
    ただし最初の週そのものが0枚だった場合は痕跡が無いので、2週目以降から数え始めることになる。
    """
    stored: dict[int, dict] = {}
    weeks = [w for w in [group.get("currentWeek")] + list(group.get("archive") or []) if w]
    starts = [(parse_time(w.get("startDate")), w) for w in weeks]
    starts = [(t, w) for t, w in starts if t is not None]
    if not starts:
        return []

    first = min(t for t, _ in starts)
    for t, week in starts:
        # startDate はその週の月曜 00:00（端末のタイムゾーン）。夏時間で1時間ずれても同じ週に落ちるよう丸める。
        index = round((t - first) / WEEK)
        if index not in stored or len(_filled(week)) > len(_filled(stored[index])):
            stored[index] = week

    last = max(max(stored), (now - first) // WEEK)
    return [
        _week_row(group, stored.get(i), first + i * WEEK, i, now)
        for i in range(last + 1)
    ]


def _filled(week: dict) -> list[dict]:
    return [s for s in week.get("slots") or [] if s.get("photoFilename") or s.get("photoURL")]


def bar(count: int, total: int, width: int = 28) -> str:
    if total <= 0:
        return ""
    return "█" * max(0, round(width * count / total))


def report(groups: list[dict], now: dt.datetime) -> None:
    if not groups:
        print("グループが1つも見つかりませんでした。")
        return

    # 3人到達は「いま3人いるか」で数える。抜けた人まで数えると、
    # 実際には2人で回っている（＝体験が成立していない）グループが到達扱いになる。
    sizes = [len(active_members(g)) for g in groups]
    ever = [len(g.get("members") or []) for g in groups]
    total = len(groups)

    print(f"\n{'=' * 62}\n  グループ数  {total}\n{'=' * 62}\n")

    # ── 3人到達率 ──
    print("■ メンバー数の分布（いま参加中の人数。抜けた人は除く）  ← 3人到達率（最大の詰まり）")
    counter = collections.Counter(sizes)
    for size in range(0, max(sizes) + 1):
        n = counter.get(size, 0)
        if n == 0 and size > 7:
            continue
        mark = "  ← 体験が成立しない" if size < 3 else ""
        print(f"   {size}人 {n:>4}  {bar(n, total)}{mark}")
    reached = sum(1 for s in sizes if s >= 3)
    print(f"\n   3人以上に到達: {reached} / {total}  = {reached / total:.0%}   （目標 60%以上）")
    ever_reached = sum(1 for s in ever if s >= 3)
    print(f"   参考: 延べ参加人数（抜けた人も含む）が3人以上: {ever_reached} / {total}"
          f"   延べ {sum(ever)}人 / いま参加中 {sum(sizes)}人 / 抜けた人 {sum(ever) - sum(sizes)}人\n")

    # ── 完成率 ──
    # 週はカレンダーから数える（week_rows 参照）。0枚で消えた週も「0枚の週」として分母に入る。
    # 今日を含む週はまだ撮れる余地があるので外す。完成は「その週の枠がすべて埋まった」で、
    # 週途中スタートの最初の週は枠が少ないので、その週の枠数と比べる。
    per_group = [week_rows(group, now) for group in groups]
    weeks = [row for rows in per_group for row in rows]
    finished = [w for w in weeks if not w["current"]]
    print("■ 週ごとの充填数  ← 完成率（カレンダー上の終わった週。0枚で消えた週も含む）")
    if finished:
        full = sum(1 for w in finished if w["slots"] and w["filled"] == w["slots"])
        near = sum(1 for w in finished if w["slots"] and w["filled"] >= w["slots"] / 2)
        missing = sum(1 for w in finished if not w["stored"])
        print(f"   終了した週: {len(finished)}   （うち記録が残っていない＝0枚の週: {missing}）")
        print(f"   全枠そろった週:      {full} / {len(finished)} = {full / len(finished):.0%}")
        print(f"   半分以上そろった週:  {near} / {len(finished)} = {near / len(finished):.0%}   （目標 70%以上）")
        dist = collections.Counter(w["filled"] for w in finished)
        for n in sorted(dist):
            print(f"     {n}枚 {dist[n]:>4}  {bar(dist[n], len(finished))}")
    else:
        print("   まだ終了した週がありません。")
    print()

    # ── R（週次継続率） ──
    # 継続は「カレンダー上の N 週目に1枚でも撮られたか」で見る。archive の長さだと、
    # 撮らなかった週が抜け落ちるので「3週目に撮った」と「3週間続いた」の区別がつかない。
    # 分母は N 週目がもう終わったグループだけ（進行中の週は、まだ撮られていないだけかもしれない）。
    print("■ N週目にも撮られたか  ← R（週次継続率。カレンダー上の週で数える）")
    horizon = max((len(rows) for rows in per_group), default=0)
    for n in range(1, horizon + 1):
        ended = [rows[n - 1] for rows in per_group if len(rows) >= n and not rows[n - 1]["current"]]
        if not ended:
            continue
        alive = sum(1 for w in ended if w["filled"] > 0)
        print(f"   {n}週目 {alive:>4} / {len(ended):<4} = {alive / len(ended):>4.0%}  {bar(alive, len(ended))}")

    week2_ended = [rows[1] for rows in per_group if len(rows) >= 2 and not rows[1]["current"]]
    week2_running = sum(1 for rows in per_group if len(rows) >= 2 and rows[1]["current"])
    week1_running = sum(1 for rows in per_group if len(rows) == 1)
    print()
    if week2_ended:
        alive = sum(1 for w in week2_ended if w["filled"] > 0)
        print(f"   2週目にも撮られた: {alive} / {len(week2_ended)} = {alive / len(week2_ended):.0%}"
              "   （2週目が終わったグループのみ）")
    else:
        print("   2週目が終わったグループがまだありません。")
    print(f"   対象外: 2週目が進行中 {week2_running} / まだ1週目 {week1_running}")
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


def write_csv(groups: list[dict], prefix: str, now: dt.datetime) -> None:
    # 既存の列（members = 延べ参加人数、weeks = 1 + archive の長さ）は意味を変えずに残し、
    # 集計と同じ定義の列を末尾に足す（activeMembers / calendarWeeks / weeksWithPhotos）。
    with open(f"{prefix}-groups.csv", "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["code", "name", "members", "weeks", "originGroupID", "updatedAt",
                         "activeMembers", "calendarWeeks", "weeksWithPhotos"])
        for g in groups:
            rows = week_rows(g, now)
            writer.writerow([
                g.get("_docID", ""),
                g.get("name", ""),
                len(g.get("members") or []),
                1 + len(g.get("archive") or []),
                g.get("originGroupID") or "",
                g.get("_updatedAt") or "",
                len(active_members(g)),
                len(rows),
                sum(1 for r in rows if r["filled"] > 0),
            ])

    # 週はカレンダー順（古い順）で、0枚で消えた週も filled=0 の行として出す（stored=False）。
    # current は「今日を含む週か」。
    with open(f"{prefix}-weeks.csv", "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["code", "group", "start", "slots", "filled", "current", "title",
                         "number", "stored"])
        for group in groups:
            for row in week_rows(group, now):
                writer.writerow([
                    row["code"], row["group"], row["start"],
                    row["slots"], row["filled"], row["current"], row["title"],
                    row["number"], row["stored"],
                ])

    print(f"書き出しました: {prefix}-groups.csv / {prefix}-weeks.csv")


def main() -> None:
    parser = argparse.ArgumentParser(description="Rotash の Firestore を集計する（読み取り専用）")
    parser.add_argument("--csv", metavar="PREFIX", help="CSV も書き出す")
    parser.add_argument("--from-file", metavar="PATH",
                        help="Firestore の代わりに手元の JSON を読む（REST の一覧レスポンス、またはグループ状態の配列）")
    parser.add_argument("--now", metavar="ISO8601",
                        help="「今日」を指定する（検証用。省略時は現在時刻）")
    args = parser.parse_args()

    now = parse_time(args.now) if args.now else dt.datetime.now(dt.timezone.utc)
    if now is None:
        sys.exit(f"--now を読めません: {args.now}")

    if args.from_file:
        print(f"読み込み中: {args.from_file} …")
        groups = load_file(args.from_file)
    else:
        project, key, collection = config()
        print(f"取得中: {project}/{collection} …")
        groups = fetch_documents(project, key, collection)
    report(groups, now)
    if args.csv:
        write_csv(groups, args.csv, now)


if __name__ == "__main__":
    main()
