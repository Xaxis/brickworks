"""changelog_merge.py REF : CHANGELOG.md for a merge of REF, when a release
was cut since REF left this branch.

A unit's entries are written under [Unreleased]. If a version was cut
meanwhile, those lines sit in the dated section on this side, and git
puts the unit's new entries beside them: into the released section, part
conflicted and part merged without a word (play127 into rel-m131, five
entries in 0.4.0's Fixed, 2026-10-21). So when this side has a version
the merge base lacks, the file is this side's, with the unit's own entries
(those its [Unreleased] gained since the base) added under [Unreleased],
and those it took out of [Unreleased] taken out of it here. An entry the
unit changed that is in a released section here is left, and named.
With no version cut since the base, nothing is done: git's merge stands.
"""
import re, subprocess, sys

VERSION = re.compile(r'^## \[(\d[^\]]*)\]', re.M)


def git(*a):
    return subprocess.run(['git', *a], capture_output=True, text=True, check=True).stdout


def unreleased(text):
    """{section: [entry]} of [Unreleased]: an entry is a bullet up to the next."""
    m = re.search(r'^## \[Unreleased\]\n(.*?)(?=^## \[)', text, re.S | re.M)
    out, sec, cur = {}, None, None
    for line in (m.group(1) if m else '').split('\n'):
        if line.startswith('### '):
            sec, cur = line[4:].strip(), None
        elif line.startswith('- '):
            cur = [line]
            out.setdefault(sec, []).append(cur)
        elif cur is not None and (line.startswith('  ') or line == ''):
            cur.append(line)
    return {s: ['\n'.join(e).rstrip() for e in es] for s, es in out.items()}


def flat(text):
    return re.sub(r'\s+', ' ', text).strip()


ref = sys.argv[1]
base_text = git('show', f"{git('merge-base', 'HEAD', ref).strip()}:CHANGELOG.md")
ours = git('show', 'HEAD:CHANGELOG.md')
if set(VERSION.findall(ours)) <= set(VERSION.findall(base_text)):
    sys.exit(0)
base, theirs = unreleased(base_text), unreleased(git('show', f'{ref}:CHANGELOG.md'))
added = {s: [e for e in es if e not in base.get(s, [])] for s, es in theirs.items()}
removed = [e for s, es in base.items() for e in es if e not in theirs.get(s, [])]

head, rest = ours.split('## [Unreleased]\n', 1)
section, tail = rest.split('\n## [', 1)
have = unreleased('## [Unreleased]\n' + section + '\n## [')
everywhere = flat(ours)
for e in removed:
    for es in have.values():
        if e in es:
            es.remove(e)
            break
    else:
        if flat(e) in everywhere:
            print(f'changelog: {ref} changed an entry already released; mend by hand: {e[:70]}')
for s, es in added.items():
    have.setdefault(s, []).extend(e for e in es if flat(e) not in everywhere)
order = ['Added', 'Changed', 'Fixed', 'Removed']
body = ''.join(f'\n### {s}\n\n' + '\n'.join(es) + '\n'
               for s, es in sorted(have.items(), key=lambda kv: order.index(kv[0]) if kv[0] in order else 9)
               if es)
open('CHANGELOG.md', 'w').write(head + '## [Unreleased]\n' + body + '\n## [' + tail)
git('add', 'CHANGELOG.md')
print(f'changelog: {ref} cut before {max(VERSION.findall(ours))}: '
      f'{sum(map(len, added.values()))} entries under [Unreleased], {len(removed)} taken out')
