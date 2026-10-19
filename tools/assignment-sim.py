#!/usr/bin/env python3
"""担当の決め方（Rotash/Services/AssignmentPlanner.swift ほか）を Python に写したシミュレーション。

Swift の手順をそのまま写してある。Swift を変えたら、ここも同じように変えること。
  - AssignmentPlanner.plan                 … 1日ずつ担当を選ぶ
  - RotashGroup.effectiveAssignmentCounts  … 新しく入った人の回数を「前からいる人の最小値」から数える
  - RotashGroup.lastTurnDays               … それぞれが最後に番だった日（入った日も番とみなす）
  - AssignmentAudit.repaired               … アプリを開くたびに、今日より先の日を組み直す
  - AppViewModel.rolledWeek                … 月曜に1週間ぶんを組む

使い方:
  python3 tools/assignment-sim.py            # 全部
  python3 tools/assignment-sim.py steady     # 人数が変わらない運用
  python3 tools/assignment-sim.py owner      # 火曜に友達が増えた週（2026-10 のオーナーの週）
  python3 tools/assignment-sim.py join       # 10週続けた3人に4人目が入る
  python3 tools/assignment-sim.py leave      # 1人抜ける

乱数は Swift（SplitMix64）と同じではないので、1回ごとの並びは一致しない。見るのは割合と最大値。
"""
import random
import statistics
import sys
from collections import Counter

# RotashFeatureFlags.turnGapAllowance。None にすると「人数+1日」の上限を外す（以前の決め方に近い）。
TURN_GAP_ALLOWANCE = 1


# ---------------------------------------------------------------------------
# AssignmentPlanner.plan

def plan(member_ids, day_indices, history=None, previous_pattern=None, previous_day_assignee=None,
         already_this_week=None, last_turn=None, max_gap=None, rng=None, stats=None):
    """戻り値は ({曜日: 担当}, {曜日: 最後に残った候補の数})。"""
    history = history or {}
    previous_pattern = previous_pattern or {}
    already_this_week = already_this_week or {}
    members = sorted(member_ids)          # Swift は uuidString の順に並べてから渡す
    if not members or not day_indices:
        return {}, {}
    days = sorted(day_indices)
    n = len(members)

    week_count = {m: already_this_week.get(m, 0) for m in members}
    week_days = len(days) + sum(week_count.values())
    base, remainder = week_days // n, week_days % n
    has_ceil = remainder > 0
    members_at_ceil = sum(1 for m in members if week_count[m] > base)

    total = {m: history.get(m, 0) for m in members}
    last_seen = dict(last_turn or {})
    result, options = {}, {}
    previous = previous_day_assignee

    def keeps_everyone_within_gap(candidate, day):
        if max_gap is None:
            return True
        deadlines = []
        for m in members:
            if m == candidate or m not in last_seen:
                continue
            deadline = last_seen[m] + max_gap
            if deadline <= day:          # 今日でないと間に合わない（すでに過ぎている）人がいる
                return False
            deadlines.append(deadline)
        for k in range(1, max_gap + 2):
            if sum(1 for d in deadlines if d <= day + k) > k:
                return False
        return True

    for day in days:
        candidates = [m for m in members
                      if week_count[m] < base
                      or (has_ceil and week_count[m] == base and members_at_ceil < remainder)]
        if not candidates:
            candidates = list(members)

        if max_gap is not None:
            within = [m for m in candidates if keeps_everyone_within_gap(m, day)]
            if within:
                candidates = within
            else:
                anyone = [m for m in members if keeps_everyone_within_gap(m, day)]
                if anyone:
                    candidates = anyone
                    if stats is not None:
                        stats["gap_over_cap"] += 1
                else:
                    # 誰を選んでも守れない（人が抜けた直後など）。いちばん長く待っている人にする。
                    waiting = [m for m in members if m in last_seen]
                    candidates = [min(waiting, key=lambda m: last_seen[m])] if waiting else candidates
                    if stats is not None:
                        stats["gap_unkeepable"] += 1

        allowed = [m for m in candidates if m != previous] or candidates
        minimum = min(total[m] for m in allowed)
        best = [m for m in allowed if total[m] == minimum]
        same = previous_pattern.get(day)
        if same is not None:
            differing = [m for m in best if m != same]
            if differing:
                best = differing

        chosen = rng.choice(best)
        result[day] = chosen
        options[day] = len(best)
        week_count[chosen] += 1
        if has_ceil and week_count[chosen] == base + 1:
            members_at_ceil += 1
        total[chosen] += 1
        last_seen[chosen] = day
        previous = chosen
    return result, options


# ---------------------------------------------------------------------------
# グループの記録（通し日番号で持つ。Swift は週の月曜からの日数で持つが、引き算すれば同じ）

class Group:
    def __init__(self, members, rng, gap_allowance=TURN_GAP_ALLOWANCE):
        self.joined = {m: None for m in members}   # None = グループを作った人
        self.active = list(members)
        self.assigned = {}                         # 通し日 -> 担当
        self.rng = rng
        self.gap_allowance = gap_allowance
        self.stats = Counter()
        self.options = {}

    def join(self, member, day):
        self.joined[member] = day
        self.active.append(member)

    def leave(self, member):
        self.active.remove(member)

    def entries(self, through):
        return [(d, m) for d, m in self.assigned.items() if d <= through]

    # RotashGroup.effectiveAssignmentCounts
    def effective_counts(self, through):
        entries = self.entries(through)
        memo = {}

        # 入るのは日の途中（Swift の joinedAt は時刻つき）なので、入った日の担当は「入る前」に数える。
        # count(m, start, end) は start の日より後、end の日まで（その日を含む）。
        def count(m, start, end):
            return sum(1 for d, x in entries if x == m and (start is None or d > start) and (end is None or d <= end))

        def baseline(m):
            if m in memo:
                return memo[m]
            joined = self.joined[m]
            if joined is None:
                memo[m] = 0
                return 0
            earlier = [x for x in self.active if x != m
                       and (self.joined[x] is None or self.joined[x] < joined)]
            memo[m] = min((effective_before(x, joined) for x in earlier), default=0)
            return memo[m]

        def effective_before(m, end):
            joined = self.joined[m]
            if joined is None:
                return count(m, None, end)
            return max(count(m, None, joined), baseline(m)) + count(m, joined, end)

        return {m: effective_before(m, None) for m in self.active}

    # RotashGroup.lastTurnDays
    def last_turn_days(self, before):
        last = {}
        for d, m in self.assigned.items():
            if d < before and m in self.active:
                last[m] = max(last.get(m, d), d)
        for m in self.active:
            joined = self.joined[m]
            if joined is not None:
                j = min(joined, before - 1)
                if m not in last or j > last[m]:
                    last[m] = j
        return last

    def max_gap(self):
        return None if self.gap_allowance is None else len(self.active) + self.gap_allowance

    def previous_pattern(self, week_start):
        return {d - (week_start - 7): m for d, m in self.assigned.items() if week_start - 7 <= d < week_start}

    # AppViewModel.rolledWeek
    def roll(self, week_start, seed):
        history = self.effective_counts(week_start - 1)
        result, options = plan(self.active, list(range(7)), history,
                               self.previous_pattern(week_start), self.assigned.get(week_start - 1),
                               {}, self.relative(self.last_turn_days(week_start), week_start),
                               self.max_gap(), random.Random(seed), self.stats)
        for d, m in result.items():
            self.assigned[week_start + d] = m
            self.options[week_start + d] = options[d]

    # AssignmentAudit.repaired（今日の担当はそのまま、明日から先を組み直す）
    def repair(self, week_start, today, seed):
        today_abs = week_start + today
        future = [d for d in range(today + 1, 7)]
        if not future:
            return
        history = self.effective_counts(today_abs)
        already = Counter(m for d, m in self.assigned.items() if week_start <= d <= today_abs)
        result, options = plan(self.active, future, history,
                               self.previous_pattern(week_start), self.assigned.get(today_abs),
                               already, self.relative(self.last_turn_days(today_abs + 1), week_start),
                               self.max_gap(), random.Random(seed), self.stats)
        for d, m in result.items():
            self.assigned[week_start + d] = m
            self.options[week_start + d] = options[d]

    @staticmethod
    def relative(last, week_start):
        return {m: d - week_start for m, d in last.items()}

    def run_week(self, week, events=None):
        """events: {曜日: fn(group, 通し日)}。その日の始まり（組み直しの前）に呼ぶ。"""
        start = 7 * week
        seed = self.rng.random()          # Swift: グループ・週・メンバーで決まる種
        self.roll(start, seed)
        for today in range(7):
            if events and today in events:
                events[today](self, start + today)
                # 抜けた人の今日の番は、ほかの人に（過ぎた日は触らない）
                if self.assigned.get(start + today) not in self.active:
                    last = self.last_turn_days(start + today)
                    self.assigned[start + today] = min(self.active, key=lambda m: last.get(m, -10**9))
                seed = self.rng.random()  # メンバーが変わると種も変わる
            self.repair(start, today, seed)

    def turn_days(self, member):
        return sorted(d for d, m in self.assigned.items() if m == member)


# ---------------------------------------------------------------------------
# 調べること

def steady(weeks=600):
    print("=== 人数が変わらない運用（%d週）" % weeks)
    print("  間隔 = 番から次の番までの日数（火曜→土曜なら4）")
    for n in range(2, 8):
        g = Group(list(range(n)), random.Random(n))
        for w in range(weeks):
            g.run_week(w)
        gaps = []
        for m in range(n):
            td = g.turn_days(m)
            gaps += [b - a for a, b in zip(td, td[1:])]
        opts = list(g.options.values())
        weekly = []
        for w in range(weeks):
            c = Counter(g.assigned[7 * w + d] for d in range(7))
            weekly.append(max(c.get(m, 0) for m in range(n)) - min(c.get(m, 0) for m in range(n)))
        totals = Counter(g.assigned.values())
        over = sum(1 for x in gaps if x > n + 1) / len(gaps)
        print(f"  {n}人  最大間隔{max(gaps):>2}日  人数+1を超えた間隔{over:6.1%}  "
              f"1人に絞れる日{sum(1 for o in opts if o == 1) / len(opts):6.1%}  "
              f"当てられる確率{statistics.mean(1 / o for o in opts):6.1%}  "
              f"週の回数差の最大{max(weekly)}  累計の差{max(totals.values()) - min(totals.values())}  "
              f"守れなかった日{sum(g.stats.values())}")


def owner(trials=4000):
    print("=== 火曜にオーナー(A)が撮り、同じ火曜に友達(C)が入った週。A の次の番は？")
    names = ["月", "火", "水", "木", "金", "土", "日"]
    for label, a_extra in [("履歴が同じ", 0), ("Aが1回多い", 1)]:
        counts = Counter()
        master = random.Random(1)
        for _ in range(trials):
            g = Group(["A", "B"], master)
            # 前の週: A と B が交互（A が1回多い場合は A を1日足す）
            for d in range(-7, 0):
                g.assigned[d] = "A" if d % 2 == 0 else "B"
            if a_extra:
                g.assigned[-8] = "A"
            seed = master.random()
            g.assigned[0] = master.choice(["A", "B"])
            g.assigned[1] = "A"
            g.join("C", 1)
            seed = master.random()
            for today in range(1, 7):
                g.repair(0, today, seed)
            nxt = next((d for d in range(2, 7) if g.assigned[d] == "A"), None)
            counts[nxt] += 1
        row = "  ".join(f"{names[d]}:{counts[d] / trials:5.1%}" for d in range(2, 7))
        print(f"  {label:<8} {row}  日曜まで来ない:{counts[None] / trials:5.1%}")


def join(trials=150):
    print("=== 3人で10週続けたところへ、水曜に4人目が入る（そのあと4週間）")
    master = random.Random(3)
    waits, shares = [], []
    for _ in range(trials):
        g = Group(["a", "b", "c"], random.Random(master.random()))
        for w in range(10):
            g.run_week(w)
        g.run_week(10, {2: lambda grp, t: grp.join("d", t)})
        for w in range(11, 14):
            g.run_week(w)
        start = 7 * 10 - 7
        mx = 0
        for m in "abc":
            td = [t for t in g.turn_days(m) if t >= start]
            mx = max([mx] + [y - x for x, y in zip(td, td[1:])])
        waits.append(mx)
        shares.append(len(g.turn_days("d")) / 26)   # 入った水曜の翌日から26日
    print(f"  前からいる人の最大の待ち: 平均{statistics.mean(waits):4.1f}日 / 最大{max(waits)}日"
          f"   新しい人の担当の割合 {statistics.mean(shares):5.1%}（4人なら25%）")


def leave(trials=500):
    print("=== 1人抜ける（その週に、人数+1日を守れない日が出た割合）")
    master = random.Random(21)
    for n in range(3, 8):
        bad, worst = 0, 0
        for _ in range(trials):
            members = list(range(n))
            g = Group(members, random.Random(master.random()))
            for w in range(6):
                g.run_week(w)
            before = sum(g.stats.values())
            gone = master.choice(members)
            day = master.randrange(1, 7)
            g.run_week(6, {day: lambda grp, t, gone=gone: grp.leave(gone)})
            for w in range(7, 9):
                g.run_week(w)
            bad += sum(g.stats.values()) > before
            limit = len(g.active) + 1
            for m in g.active:
                td = [t for t in g.turn_days(m) if t >= 42]
                worst = max([worst] + [y - x - limit for x, y in zip(td, td[1:])])
        print(f"  {n}人→{n - 1}人  守れない日が出た週 {bad / trials:6.2%}   上限を超えた最大 {max(0, worst)}日")


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    for name, fn in [("steady", steady), ("owner", owner), ("join", join), ("leave", leave)]:
        if which in ("all", name):
            fn()
            print()
