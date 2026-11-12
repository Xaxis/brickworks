// A sub-file's name in an LDraw file, as LDraw's own readers take it
// (LdrModel._key, LdrModel.file_name_of, LdrModel.reference_of). A FILE
// line's name is its text after the word, and a placing line's reference its
// text after the fourteenth field, each as written with its space trimmed;
// the two are compared in any case, "\" and "/" the same, and nothing else.
// "Gate .ldr" is not "Gate.ldr", nor "parts\twin.ldr" "twin.ldr", nor
// "hssub.ldr.ldr" "hssub.ldr": read as a bare stem, each pair was one file,
// and one of them was lost (se3check, hscheck). The first block of a name is
// the one a reference means, as LDView reads a file (LDLModel::readComment).

/// What LDraw's readers take for space round a name: C's isspace.
const SPACE = /^[ \t\n\v\f\r]+|[ \t\n\v\f\r]+$/g;

/// [text] with what LDraw takes for space trimmed off its ends, and nothing
/// else: a line ending in a sub-model's name of control characters keeps it.
export function trimSpace(text) {
  return String(text).replace(SPACE, "");
}

/// A sub-file's name as LDraw compares it, a FILE's and a reference's alike.
export function keyOf(name) {
  return trimSpace(name).replace(/\\/g, "/").toLowerCase();
}

/// A part's number from the name a reference gives it: no folder, no
/// extension, lower case (LdrModel.stem).
export function stemOf(name) {
  let text = keyOf(name);
  text = text.slice(text.lastIndexOf("/") + 1);
  for (const suffix of [".ldr", ".dat", ".mpd"]) {
    if (text.endsWith(suffix)) return text.slice(0, -suffix.length);
  }
  return text;
}

/// [line] after its first [count] fields, as written, its space trimmed: a
/// FILE line's name (2), a placing line's reference (14). A name with two
/// spaces in a row keeps them: 8840-1_B-Model's sub-models are named so.
export function afterFields(line, count) {
  const rest = trimSpace(line);
  const at = new RegExp(`^(?:[^ \\t\\n\\v\\f\\r]+[ \\t\\n\\v\\f\\r]+){${count}}`).exec(rest);
  return at ? rest.slice(at[0].length) : "";
}

/// The key the model's own section goes by in a file of FILE sections, the
/// first FILE's: one no reference gives, a name never being space at its
/// ends (LdrModel.MAIN_KEY). LDView puts the model's own block in no table,
/// so a later block of its name is the one a reference to the name means.
export const MAIN_KEY = " ";

/// The key of the section a FILE line naming [name] begins, [blocks] the
/// count of each name's blocks so far (a Map, from empty for a file's first
/// FILE line): the model's own by MAIN_KEY, the first block of a name by its
/// name (keyOf), and a later one by a key no reference gives
/// (LdrModel.section_key).
export function sectionKey(name, blocks) {
  if (blocks.size === 0) {
    blocks.set(MAIN_KEY, 1);
    return MAIN_KEY;
  }
  const key = keyOf(name);
  const seen = (blocks.get(key) || 0) + 1;
  blocks.set(key, seen);
  return seen === 1 ? key : `${key}\n${seen}`;
}
