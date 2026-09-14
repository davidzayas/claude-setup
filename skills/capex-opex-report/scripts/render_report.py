#!/usr/bin/env python3
"""Render the capitalization report HTML from classification.json.

classification.json shape (write this by hand after reading prompts.md):
{
  "since": "2026-08-15", "until": "2026-09-14",
  "prepared_by": "Name", "prepared_for": "Finance",
  "projects": [
    {"name": "repo", "summary": "One or two sentences on what the work was.",
     "sessions": [{"id": "f0f5c76f", "hours": 27.0, "capex_share": 0.9}],
     "sandbox": {"runs": 19, "hours": 1.08, "capex_share": 1.0}}   # optional: automated runs folded into the project
  ],
  "capex_rationale": "...", "opex_rationale": "...",
  "excluded": ["oryn"], "excluded_reason": "personal projects",
  "extra_method_notes": []
}
All totals, percentages, and dominant-category counts are computed here, never typed.
"""
import argparse, datetime as dt, html, json, os, re, sys

RULE_TEXT = ("Work on internal-use software that has not yet been placed in service is capitalized during the "
             "application development stage. That includes building, testing, defect correction, and first deployment. "
             "Maintenance of software already in service, developer tooling upkeep, and evaluations are expensed.")

def esc(s): return html.escape(s or "", quote=True)
def fmt_date(s):
    d = dt.date.fromisoformat(s)
    return f"{d.strftime('%b')} {d.day}, {d.year}"
def fmt_range(a, b):
    da, db = dt.date.fromisoformat(a), dt.date.fromisoformat(b)
    if da.year == db.year:
        return f"{da.strftime('%b')} {da.day} – {db.strftime('%b')} {db.day}, {db.year}"
    return f"{fmt_date(a)} – {fmt_date(b)}"
def pct(part, whole): return round(100 * part / whole) if whole else 0

def split_cell(c, o):
    """Percent labels + mini bar. c/o are shares in [0,1]; labels always sum to 100."""
    cp = round(c * 100); op = 100 - cp if (c or o) else 0
    left = f'<span class="c">{cp}%</span>' if cp else '<span class="z">—</span>'
    right = f'<span class="o">{op}%</span>' if op else '<span class="z">—</span>'
    bars = ""
    if c > 0: bars += f'<i class="c" style="flex:{c*100:.1f}"></i>'
    if o > 0: bars += f'<i class="o" style="flex:{o*100:.1f}"></i>'
    return f'<div class="pct">{left}{right}</div><div class="mini">{bars}</div>'

def weight_row(title, sub, cap, opx, cap_tip, opx_tip):
    cp = pct(cap, cap + opx); op = 100 - cp if (cap + opx) else 0
    return f'''        <div class="weight">
          <div class="label"><b>{esc(title)}</b>{esc(sub)}</div>
          <div class="bar" role="img" aria-label="{esc(title)}: capex {cp} percent, opex {op} percent">
            <div class="seg capex" style="flex:{cp}" tabindex="0" data-tip="<b>Capex</b> {esc(cap_tip)}"><span class="v">{cp}%</span></div>
            <div class="seg opex" style="flex:{op}" tabindex="0" data-tip="<b>Opex</b> {esc(opx_tip)}"><span class="v">{op}%</span></div>
          </div>
        </div>'''

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("classification")
    ap.add_argument("--out", required=True)
    ap.add_argument("--template", default=os.path.join(os.path.dirname(__file__), "..", "templates", "report.html"))
    a = ap.parse_args()
    with open(a.classification, encoding="utf-8") as fh:
        C = json.load(fh)
    projects = C["projects"]
    def check(v, lo, hi, what, where):
        if not isinstance(v, (int, float)) or not (lo <= v <= hi):
            sys.exit(f"classification.json: {what} must be a number in [{lo}, {hi}] ({where}, got {v!r})")
    for p in projects:
        sb = p.get("sandbox") or {}
        if not p.get("sessions") and not sb:
            sys.exit(f"classification.json: project {p.get('name')!r} has no sessions")
        for s in p["sessions"]:
            check(s.get("capex_share"), 0, 1, "capex_share", f"{p['name']}/{s.get('id')}")
            check(s.get("hours"), 0, 1e6, "hours", f"{p['name']}/{s.get('id')}")
        if sb:
            check(sb.get("hours", 0), 0, 1e6, "sandbox.hours", p["name"])
            check(sb.get("capex_share", 0), 0, 1, "sandbox.capex_share", p["name"])
        p["hours"] = sum(s["hours"] for s in p["sessions"]) + sb.get("hours", 0)
        p["capex_h"] = sum(s["hours"] * s["capex_share"] for s in p["sessions"]) + sb.get("hours", 0) * sb.get("capex_share", 0)
        p["share"] = p["capex_h"] / p["hours"] if p["hours"] else 0
    projects.sort(key=lambda p: -p["hours"])

    total_h = sum(p["hours"] for p in projects)
    capex_h = sum(p["capex_h"] for p in projects)
    opex_h = total_h - capex_h
    n_sess = sum(len(p["sessions"]) for p in projects)
    sess_cap = sum(1 for p in projects for s in p["sessions"] if s["capex_share"] >= 0.5)
    proj_cap = sum(1 for p in projects if p["share"] >= 0.5)
    if total_h <= 0:
        sys.exit("classification.json: total hours are zero, nothing to report")
    capex_pct = pct(capex_h, total_h)

    opex_projects = sorted([p for p in projects if p["share"] < 0.5], key=lambda p: -(p["hours"] - p["capex_h"]))
    if opex_projects:
        top = opex_projects[0]
        hero = (f"<b>{capex_h:.1f} hours capex</b> of {total_h:.1f} active hours. The remaining <b>{opex_h:.1f} hours</b> are opex, "
                f"and {top['hours'] - top['capex_h']:.1f} of those are one project: {esc(top['name'])}.")
    else:
        hero = f"<b>{capex_h:.1f} hours capex</b> of {total_h:.1f} active hours. The remaining <b>{opex_h:.1f} hours</b> are opex."

    weights = "\n".join([
        weight_row("By active time", f"{total_h:.1f} hours", capex_h, opex_h, f"{capex_h:.1f} h · {capex_pct}%", f"{opex_h:.1f} h · {100-capex_pct}%"),
        weight_row("By project", f"{len(projects)} projects, dominant category", proj_cap, len(projects) - proj_cap,
                   f"{proj_cap} of {len(projects)} projects", f"{len(projects)-proj_cap} of {len(projects)} projects"),
        weight_row("By session", f"{n_sess} sessions, dominant category", sess_cap, n_sess - sess_cap,
                   f"{sess_cap} of {n_sess} sessions", f"{n_sess-sess_cap} of {n_sess} sessions"),
    ])

    rows = []
    for p in projects:
        rows.append(f'''      <tr>
        <td class="proj">{esc(p["name"])}</td><td class="num">{len(p["sessions"])}</td><td class="num">{p["hours"]:.1f}</td>
        <td class="split">{split_cell(p["share"], 1 - p["share"])}</td>
        <td class="sum">{esc(p["summary"])}</td>
      </tr>''')

    excluded = C.get("excluded") or []
    method = [
        f"<li><b>Source.</b> Local Claude Code session transcripts for every project on this machine, filtered to activity between {fmt_date(C['since'])} and {fmt_date(C['until'])}.</li>",
        "<li><b>Active time.</b> Sum of gaps between consecutive transcript events, each gap capped at 10 minutes, so idle stretches inside multi-day sessions are not counted. Sessions that began before the window contribute only their in-window activity.</li>",
        "<li><b>Mixed sessions.</b> Where a session contained both capex and opex work, the split is proportional to tool calls per day.</li>",
        "<li><b>Grouping.</b> Sessions are rolled up by repository. Duplicated transcripts of one session are counted once, and automated sandbox test runs are folded into the project that spawned them.</li>",
    ]
    if excluded:
        reason = f" ({esc(C['excluded_reason'])})" if C.get("excluded_reason") else ""
        method.append(f"<li><b>Excluded.</b> The {esc(', '.join(excluded))} {'repositories' if len(excluded) > 1 else 'repository'}{reason}, empty sessions, and the session that produced this report.</li>")
    else:
        method.append("<li><b>Excluded.</b> Empty sessions and the session that produced this report.</li>")
    for n in C.get("extra_method_notes") or []:
        method.append(f"<li>{esc(n)}</li>")

    with open(a.template, encoding="utf-8") as fh:
        t = fh.read()
    period = fmt_range(C["since"], C["until"])
    subs = {
        "%%N_PROJECTS%%": str(len(projects)), "%%PERIOD%%": period,
        "%%PERIOD_LEDE%%": f"for the period {period}",
        "%%PREPARED_BY%%": esc(C.get("prepared_by", "")), "%%PREPARED_FOR%%": esc(C.get("prepared_for", "Finance")),
        "%%BASIS%%": esc(C.get("basis", "ASC 350-40 lifecycle stage")),
        "%%CAPEX_PCT%%": str(capex_pct), "%%HERO_CAPTION%%": hero, "%%WEIGHT_ROWS%%": weights,
        "%%PROJECT_ROWS%%": "\n".join(rows), "%%N_SESSIONS%%": str(n_sess), "%%TOTAL_H%%": f"{total_h:.1f}",
        "%%TOTAL_SPLIT%%": split_cell(capex_h / total_h, opex_h / total_h),
        "%%CAPEX_H%%": f"{capex_h:.1f}", "%%OPEX_H%%": f"{opex_h:.1f}",
        "%%RULE_TEXT%%": esc(C.get("rule_text") or RULE_TEXT),
        "%%CAPEX_RATIONALE%%": esc(C.get("capex_rationale", "")), "%%OPEX_RATIONALE%%": esc(C.get("opex_rationale", "")),
        "%%METHOD_ITEMS%%": "\n".join("    " + m for m in method),
    }
    # Single pass against the original template, so substituted content can never be re-matched.
    unfilled = set(re.findall(r"%%[A-Z_]+%%", t)) - set(subs)
    if unfilled:
        sys.exit(f"template has placeholders without values: {sorted(unfilled)}")
    t = re.sub(r"%%[A-Z_]+%%", lambda m: subs[m.group(0)], t)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, "w", encoding="utf-8") as fh:
        fh.write(t)
    print(f"{'project':30} {'sess':>4} {'hours':>7} {'capex':>6}")
    for p in projects:
        print(f"{p['name'][:30]:30} {len(p['sessions']):4} {p['hours']:7.2f} {100*p['share']:5.0f}%")
    print(f"projects {len(projects)}  sessions {n_sess}  total {total_h:.1f} h  capex {capex_h:.1f} h ({100*capex_h/total_h:.1f}%)  "
          f"opex {opex_h:.1f} h  project-dominant capex {proj_cap}/{len(projects)}  session-dominant capex {sess_cap}/{n_sess}")
    print("wrote", a.out)

if __name__ == "__main__":
    main()
