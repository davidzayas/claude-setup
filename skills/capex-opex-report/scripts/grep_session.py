#!/usr/bin/env python3
"""grep_session.py <session-id-prefix or path> [--since D --until D] [--pattern REGEX]

Digest of one transcript for classification: PR number -> title map harvested from
assistant text and tool results, plus lifecycle-stage evidence lines (alpha, beta,
TestFlight, not live, first deploy, feature branch, merged, deployed...).
"""
import argparse, glob, json, os, re, sys

STAGE = (r"\b(alpha|beta|TestFlight|not (yet )?(live|merged|submitted|released|shipped)|go[- ]live|first deploy|feature branch|"
         r"feature/[\w.-]+|hand-test\w*|unmerged|unlisted|pre-bumped|placed in service|in production|prod(uction)? deploy\w*|"
         r"deployed to|shipped|released|store (release|submission|listing)|password gate|behind a (shared )?password|access password)\b")

def texts_of(e):
    m = e.get("message") if isinstance(e.get("message"), dict) else {}
    c = m.get("content")
    out = []
    if isinstance(c, str):
        out.append(c)
    elif isinstance(c, list):
        for b in c:
            if not isinstance(b, dict):
                continue
            if b.get("type") == "text":
                out.append(b["text"])
            elif b.get("type") == "tool_result":
                cc = b.get("content")
                if isinstance(cc, str):
                    out.append(cc)
                elif isinstance(cc, list):
                    out += [x.get("text", "") for x in cc if isinstance(x, dict)]
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("session")
    ap.add_argument("--since", default="0000")
    ap.add_argument("--until", default="9999")
    ap.add_argument("--pattern", default=STAGE, help="regex for evidence lines")
    ap.add_argument("--max", type=int, default=40)
    a = ap.parse_args()
    path = a.session
    if not os.path.exists(path):
        hits = glob.glob(os.path.join(glob.escape(os.path.expanduser("~/.claude/projects")), "*", glob.escape(a.session) + "*.jsonl"))
        if len(hits) != 1:
            sys.exit(f"{len(hits)} transcripts match {a.session!r}: {hits}")
        path = hits[0]
    titles, ev, seen = {}, [], set()
    pat = re.compile(a.pattern, re.I)
    for line in open(path, encoding="utf-8", errors="replace"):
        try:
            e = json.loads(line)
        except Exception:
            continue
        if not isinstance(e, dict) or e.get("isSidechain"):
            continue
        ts = (e.get("timestamp") or "")[:16]
        if not (a.since <= ts[:10] <= a.until):
            continue
        role = ((e.get("message") if isinstance(e.get("message"), dict) else {}) or {}).get("role") or e.get("type")
        for t in texts_of(e):
            for mm in re.finditer(r'\|\s*\[?#(\d+)\]?(?:\([^)]*\))?\s*\|\s*\**([^|\n]{6,140}?)\**\s*\|', t):
                titles.setdefault(mm.group(1), mm.group(2).strip())
            for mm in re.finditer(r'(?:PR\s*)?#(\d+)\s*[:(—-]\s*"?([A-Z][^)\n"]{6,120})', t):
                titles.setdefault(mm.group(1), mm.group(2).strip())
            for mm in re.finditer(r'"number":\s*(\d+)[\s\S]{0,400}?"title":\s*"([^"]{6,140})"', t):
                titles.setdefault(mm.group(1), mm.group(2))
            if role == "assistant" and len(ev) < a.max:
                for mm in pat.finditer(t):
                    s = max(0, mm.start() - 140)
                    snip = re.sub(r"\s+", " ", t[s:mm.end() + 140])
                    if snip[:60] in seen:
                        continue
                    seen.add(snip[:60])
                    ev.append(f"[{ts}] …{snip}…")
                    break
    print(f"# {os.path.basename(path)}\n\n## PRs mentioned ({len(titles)}; a superset of PRs reviewed, status tables name others)")
    for k in sorted(titles, key=int):
        print(f"- #{k} {titles[k][:120]}")
    print(f"\n## Stage evidence ({len(ev)})")
    print("\n".join(ev))

if __name__ == "__main__":
    main()
