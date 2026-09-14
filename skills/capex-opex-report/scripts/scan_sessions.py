#!/usr/bin/env python3
"""Scan local Claude Code transcripts and emit per-session activity for a date window.

Outputs (in --out dir):
  sessions.json  one record per top-level session with in-window activity
  prompts.md     user prompts grouped by project -> session, for classification
Prints a per-project summary table.

Only top-level <project>/<session>.jsonl files are read. Subagent transcripts
(<project>/<session>/subagents/*.jsonl) are skipped because their timestamps
already fall inside the parent session's gaps. Sidechain entries inside a
transcript are real activity and count toward active time, but their text is
not surfaced as prompts.

Projects are keyed by the full working directory recorded in the transcript;
the folder name is only the display label, disambiguated with its parent when
two different paths share a name.
"""
import argparse, collections, datetime as dt, glob, json, os, re, sys

UTC = dt.timezone.utc
GAP_CAP_SEC = 600          # a silence longer than this counts as 10 min, not the full gap
FORK_MIN_SHARED = 20       # transcripts sharing this many event uuids are one forked session
SKIP_PREFIXES = ("<local-command", "<command-", "<task-notification", "<ci-monitor", "<bash-", "<system-reminder")
# Sandbox runs: automated test sessions a parent session spawned in its scratchpad.
# The default matches Claude Code's scratchpad layout: .../<encoded-project-path>/<session-uuid>/scratchpad/...
SANDBOX_DEFAULT = r"([A-Za-z0-9._-]+?)[-/][0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[-/]scratchpad"

def parse_ts(s):
    try:
        t = dt.datetime.fromisoformat(s.replace("Z", "+00:00"))
    except Exception:
        return None
    return t if t.tzinfo else t.replace(tzinfo=UTC)

def user_text(o):
    c = (o.get("message") or {}).get("content")
    if isinstance(c, str):
        txt = c
    elif isinstance(c, list):
        txt = "\n".join(p.get("text", "") for p in c if isinstance(p, dict) and p.get("type") == "text")
    else:
        return None
    txt = re.sub(r"<system-reminder>.*?</system-reminder>", "", txt, flags=re.S)
    cmd = re.search(r"<command-name>([^<]+)</command-name>", txt)
    if cmd:  # a slash command: keep its name and arguments, they are often the whole workload
        args = re.search(r"<command-args>([^<]*)", txt)
        return (cmd.group(1) + " " + (args.group(1).strip() if args else "")).strip()
    txt = re.sub(r"\s+", " ", txt).strip()
    if not txt or txt.startswith(SKIP_PREFIXES):
        return None
    return txt

def scan_file(path, since, until):
    ts, prompts, cwd = [], [], None
    uuids, tool_events = set(), {}          # tool_events: uuid -> (day, n_tool_uses), in-window assistant turns
    first_prompt = None
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                o = json.loads(line)
            except Exception:
                continue
            if not isinstance(o, dict):
                continue
            cwd = cwd or o.get("cwd")
            if o.get("uuid"):
                uuids.add(o["uuid"])
            t = parse_ts(o.get("timestamp") or "")
            if not t:
                continue
            if o.get("type") == "user" and not o.get("isMeta") and not o.get("isSidechain") and first_prompt is None:
                txt = user_text(o)
                if txt:
                    first_prompt = (t, txt[:120])
            if t < since or t > until:
                continue
            ts.append(t)
            if o.get("isSidechain"):
                continue
            day = t.strftime("%Y-%m-%d")
            if o.get("type") == "assistant":
                c = (o.get("message") or {}).get("content")
                n = sum(1 for p in c if isinstance(p, dict) and p.get("type") == "tool_use") if isinstance(c, list) else 0
                tool_events[o.get("uuid") or f"{path}:{len(tool_events)}"] = (day, n)
            elif o.get("type") == "user" and not o.get("isMeta"):
                txt = user_text(o)
                if txt:
                    prompts.append((t.strftime("%m-%d %H:%M"), txt[:240]))
    if not ts:
        return None
    ts.sort()
    return dict(cwd=cwd, ts=ts, uuids=uuids, tool_events=tool_events, prompts=prompts,
                first_prompt=first_prompt[1] if first_prompt else None)

def finish(s):
    """Derive the reported fields from raw timestamps and tool events (used for singles and unions)."""
    ts = sorted(set(s["ts"]))
    s["first"], s["last"], s["n_events"] = ts[0], ts[-1], len(ts)
    s["active_min"] = round(sum(min((b - a).total_seconds(), GAP_CAP_SEC) for a, b in zip(ts, ts[1:])) / 60, 1)
    days = collections.Counter()
    for day, n in s["tool_events"].values():
        days[day] += n
    s["tools_by_day"], s["n_tools"] = dict(sorted(days.items())), sum(days.values())
    s["prompts"] = sorted(set(s["prompts"]))

def encode_path(path):
    """Claude Code's transcript folder name for a working directory: / and . become -."""
    return re.sub(r"[/.]", "-", path.rstrip("/"))

def project_of(cwd, dirname, sandbox_re):
    """(key, display, is_sandbox). For a sandbox run the key is the parent's encoded
    project path; it is resolved to the parent's real key once all sessions are read."""
    src = cwd or dirname
    m = sandbox_re.search(src)
    if m:
        return m.group(1), m.group(1), True
    if "scratchpad" in src:
        print(f"warning: {src} looks like a scratchpad but does not match --sandbox-pattern; counted as its own project", file=sys.stderr)
    if "scratch-workspaces" in src:
        return "no-folder-scratch", "no-folder-scratch", False
    if cwd:
        cwd = cwd.rstrip("/")
        return cwd, os.path.basename(cwd) or cwd, False
    return dirname, dirname, False

def main():
    ap = argparse.ArgumentParser()
    today = dt.date.today()
    ap.add_argument("--since", default=(today - dt.timedelta(days=30)).isoformat())
    ap.add_argument("--until", default=today.isoformat())
    ap.add_argument("--exclude", default="", help="comma-separated project names to drop")
    ap.add_argument("--exclude-session", default="", help="comma-separated session id prefixes to drop (e.g. the one producing the report)")
    ap.add_argument("--out", required=True)
    ap.add_argument("--projects-dir", default=os.path.expanduser("~/.claude/projects"))
    ap.add_argument("--sandbox-pattern", default=SANDBOX_DEFAULT, help="regex; group 1 is the parent project name")
    a = ap.parse_args()
    since = dt.datetime.fromisoformat(a.since).replace(tzinfo=UTC)
    until = dt.datetime.fromisoformat(a.until).replace(tzinfo=UTC) + dt.timedelta(days=1)
    excl = {x.strip() for x in a.exclude.split(",") if x.strip()}
    excl_sess = tuple(x.strip() for x in a.exclude_session.split(",") if x.strip())
    sandbox_re = re.compile(a.sandbox_pattern)
    os.makedirs(a.out, exist_ok=True)

    sessions = []
    for f in sorted(glob.glob(os.path.join(glob.escape(a.projects_dir), "*", "*.jsonl"))):
        r = scan_file(f, since, until)
        if not r:
            continue
        key, name, sandbox = project_of(r["cwd"], os.path.basename(os.path.dirname(f)), sandbox_re)
        if excl_sess and os.path.basename(f).startswith(excl_sess):
            continue
        r.update(project_key=key, project=name, sandbox=sandbox, session_id=os.path.basename(f)[:-6], path=f)
        sessions.append(r)

    # Sandbox runs: adopt the key and name of the session whose project path they encode.
    by_encoded = {encode_path(s["project_key"]): s for s in sessions if not s["sandbox"] and s["cwd"]}
    for s in sessions:
        if s["sandbox"]:
            parent = by_encoded.get(s["project_key"])
            if parent:
                s["project_key"], s["project"] = parent["project_key"], parent["project"]
            else:
                s["project"] = re.sub(r"^.*?-playground-|^-Users-[^-]+-[^-]+-", "", s["project_key"]) or s["project_key"]
                print(f"warning: sandbox run {s['session_id'][:8]} has no parent session in the window; listed as {s['project']}", file=sys.stderr)

    # Exclusions apply after sandbox runs have adopted their parent's name.
    sessions = [s for s in sessions if s["project"] not in excl and s["project_key"] not in excl]

    # Display names: disambiguate different paths that share a folder name.
    by_name = collections.defaultdict(set)
    for s in sessions:
        by_name[s["project"]].add(s["project_key"])
    for s in sessions:
        if len(by_name[s["project"]]) > 1 and not s["sandbox"]:
            s["project"] = os.path.join(os.path.basename(os.path.dirname(s["project_key"])), s["project"])

    # Forked/resumed sessions leave several transcripts sharing a prefix of identical event uuids.
    # Group by shared uuids (never by prompt text) and count each group's union once.
    for s in sessions:
        s["group"] = s["session_id"]
    real = [s for s in sessions if not s["sandbox"]]
    for i, x in enumerate(real):
        for y in real[i + 1:]:
            if x["project_key"] == y["project_key"] and len(x["uuids"] & y["uuids"]) >= FORK_MIN_SHARED:
                gx, gy = x["group"], y["group"]
                for s in real:
                    if s["group"] == gy:
                        s["group"] = gx
    groups = collections.defaultdict(list)
    for s in sessions:
        groups[s["group"]].append(s)
    for group in groups.values():
        if len(group) > 1:
            group.sort(key=lambda s: (s["ts"][-1], len(s["ts"])), reverse=True)
            keep = group[0]
            for d in group[1:]:
                keep["ts"] = keep["ts"] + d["ts"]
                keep["tool_events"] = {**d["tool_events"], **keep["tool_events"]}
                keep["prompts"] = keep["prompts"] + d["prompts"]
                d["duplicate_of"] = keep["session_id"]
    for s in sessions:
        finish(s)
        s["forked"] = any(x.get("duplicate_of") == s["session_id"] for x in sessions)
        for k in ("ts", "uuids", "tool_events", "group"):
            del s[k]

    # Trivial sessions: almost no tool use (an opened-and-closed window, a /login, a /plugin install).
    for s in sessions:
        s["trivial"] = s["n_tools"] < 3 and not s["sandbox"]

    counted = [s for s in sessions if not s.get("duplicate_of") and not s["trivial"]]
    proj = collections.OrderedDict()
    for s in sorted(counted, key=lambda s: s["first"]):
        p = proj.setdefault(s["project"], dict(sessions=0, sandbox_runs=0, sandbox_min=0.0, active_min=0.0, prompts=0))
        if s["sandbox"]:
            p["sandbox_runs"] += 1
            p["sandbox_min"] += s["active_min"]
        else:
            p["sessions"] += 1
        p["active_min"] += s["active_min"]
        p["prompts"] += len(s["prompts"])

    out = dict(since=a.since, until=a.until, excluded=sorted(excl),
               sessions=[{**s, "first": s["first"].isoformat(), "last": s["last"].isoformat()} for s in sessions])
    with open(os.path.join(a.out, "sessions.json"), "w", encoding="utf-8") as fh:
        json.dump(out, fh, indent=1, ensure_ascii=False)

    with open(os.path.join(a.out, "prompts.md"), "w", encoding="utf-8") as fh:
        fh.write(f"# User prompts {a.since} to {a.until}\n\n")
        for name in sorted(proj, key=lambda n: -proj[n]["active_min"]):
            p = proj[name]
            fh.write(f"\n## {name}  ({p['sessions']} sessions, {p['active_min']/60:.2f} h)\n")
            for s in sorted(counted, key=lambda s: s["first"]):
                if s["project"] != name or s["sandbox"]:
                    continue
                fork = "  (union of forked transcripts)" if s["forked"] else ""
                fh.write(f"\n### session {s['session_id'][:8]}  {s['first'].isoformat()[:16]} -> {s['last'].isoformat()[5:16]}  hours {s['active_min']/60:.2f}{fork}\n")
                fh.write(f"tool calls by day: {s['tools_by_day']}\n\n")
                for t, txt in s["prompts"]:
                    fh.write(f"- [{t}] {txt}\n")
            if p["sandbox_runs"]:
                fh.write(f"\n### sandbox: {p['sandbox_runs']} automated runs, hours {p['sandbox_min']/60:.2f} (put in classification.json as the project's \"sandbox\" block)\n")

    print(f"window {a.since}..{a.until}  projects {len(proj)}  sessions {sum(p['sessions'] for p in proj.values())}  "
          f"forks merged {sum(1 for s in sessions if s.get('duplicate_of'))}  trivial {sum(1 for s in sessions if s['trivial'])}")
    print(f"{'project':34} {'sess':>4} {'sbx':>4} {'hours':>7} {'sbx_h':>6} {'prompts':>7}")
    for name in sorted(proj, key=lambda n: -proj[n]["active_min"]):
        p = proj[name]
        print(f"{name:34} {p['sessions']:4} {p['sandbox_runs']:4} {p['active_min']/60:7.2f} {p['sandbox_min']/60:6.2f} {p['prompts']:7}")
    print(f"\nwrote {a.out}/sessions.json and prompts.md")

if __name__ == "__main__":
    main()
