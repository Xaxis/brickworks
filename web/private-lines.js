// What a model file says of the person who made it without their asking,
// left out of a shared copy (byreview, 2026-11-21): anyone with a model's
// link can download its file, and a program writes things in a file its
// builder never sees. The page that shares a file (web/share-model.js) says
// what it left out; the server (api/share.js publish) leaves the same out of
// whatever is published, from the app, the connector or the page.
//
//   An Author line that holds an email address (LDCad and MLCad fill it in
//   from their settings) goes, line and all.
//   A line of a program's own settings that names a place on the builder's
//   computer (C:\Users\..., /home/..., /Users/..., a network share's
//   \\server\...) goes too: a background picture, a folder of parts, which
//   mean nothing on anybody else's computer. A Name: line keeps its file's
//   own name without the folders before it, and a FILE line is left as it is,
//   since the model's part lines name its sections by it.
//
// Only comment and meta lines (type 0) are read: a part line is the model.
//
//   withoutPrivateLines(text) -> {text, emails, paths}
//     text     the file with those lines left out (the same string when none)
//     emails   how many Author lines with an email address went
//     paths    how many lines naming a place on a computer went or were cut

const EMAIL = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/;
/// An Author line: LDraw's own, or a program's (0 !LEOCAD MODEL AUTHOR ...).
const AUTHOR = /^0\s+(?:Author:|!\S+(?:\s+\S+)?\s+AUTHOR\b)/i;
/// A place on somebody's computer, where a path starts: a drive (C:\, D:/),
/// a network share (\\server\), or a home or a disk on a Mac or Linux.
const PATH = /(?:^|[\s"'=(\[,;/])(?:[A-Za-z]:[\\/]|\\\\[^\\\s]+\\|\/(?:home|Users|root|Volumes|media|mnt|run\/media|private|var\/folders)\/)/;
/// The structural lines: a section's start and end.
const SECTION = /^0\s+(?:FILE|NOFILE)\b/i;
const NAME = /^(0\s+Name:\s*)(.*)$/i;

export function withoutPrivateLines(given) {
  if (typeof given !== "string") return { text: given, emails: 0, paths: 0 };
  // Nothing to look at: the common case costs one test.
  if (!EMAIL.test(given) && !PATH.test(given)) return { text: given, emails: 0, paths: 0 };
  let emails = 0;
  let paths = 0;
  const pieces = given.split(/(\r\n|\r|\n)/);
  const out = [];
  for (let at = 0; at < pieces.length; at += 2) {
    const raw = pieces[at];
    const end = pieces[at + 1] ?? "";
    const line = raw.trim();
    if (!/^0(?:\s|$)/.test(line) || SECTION.test(line)) {
      out.push(raw, end);
      continue;
    }
    if (AUTHOR.test(line) && EMAIL.test(line)) {
      emails += 1;
      continue;
    }
    if (PATH.test(line)) {
      paths += 1;
      const named = line.match(NAME);
      if (named) out.push(`${named[1]}${named[2].split(/[\\/]/).pop()}`, end);
      continue;
    }
    out.push(raw, end);
  }
  if (!emails && !paths) return { text: given, emails: 0, paths: 0 };
  return { text: out.join(""), emails, paths };
}
