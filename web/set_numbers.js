// The set numbers a person gives Add sets on Your lists (web/lists.js,
// lists2a): typed, or in a file Rebrickable, BrickLink or Brickset made.
// No imports, so tests/test_lists_import.py runs it as the page does and
// holds its preview to the rows it computes from three real files.

/// The set numbers in [text]: typed ("10497, 6080-1") or a file's
/// (Rebrickable's Set Number, Brickset's Number and Variant, BrickLink's
/// <ITEMID> of type S), each once.
export function setNumbersIn(text) {
  const found = [];
  // A file saved by a spreadsheet may begin with a byte-order mark, which
  // would hide its first heading.
  const source = String(text || "").replace(/^\uFEFF/, "");
  if (/<INVENTORY>/i.test(source)) {
    for (const item of source.matchAll(/<ITEM>([\s\S]*?)<\/ITEM>/gi)) {
      if (!/<ITEMTYPE>\s*S\s*<\/ITEMTYPE>/i.test(item[1])) continue;
      const id = /<ITEMID>\s*([^<\s]+)\s*<\/ITEMID>/i.exec(item[1]);
      if (id) found.push(id[1]);
    }
  } else {
    const lines = source.split(/\r?\n/);
    const head = (lines[0] || "").toLowerCase().split(",").map((one) => one.replace(/^"|"$/g, "").trim());
    const at = head.findIndex((one) => ["set number", "set_num", "number", "set"].includes(one));
    const variant = head.indexOf("variant");
    if (at >= 0 && head.length > 1) {
      for (const line of lines.slice(1)) {
        const cells = line.split(",").map((one) => one.replace(/^"|"$/g, "").trim());
        if (!cells[at]) continue;
        found.push(variant >= 0 && cells[variant] && !/-\d+$/.test(cells[at]) ? `${cells[at]}-${cells[variant]}` : cells[at]);
      }
    } else {
      found.push(...source.split(/[\s,;]+/).filter((one) => /^[0-9a-z][0-9a-z._-]*$/i.test(one)));
    }
  }
  return [...new Set(found.map((one) => (/-\d{1,3}$/.test(one) ? one : `${one}-1`).toLowerCase()))].slice(0, 2000);
}

/// What a file is, from its first line: BrickLink's XML, Brickset's CSV
/// (Number with QtyOwned, Own or Want) or Rebrickable's.
export function kindOf(text) {
  const source = String(text || "").replace(/^\uFEFF/, "");
  if (/^\s*(<\?xml|<INVENTORY)/i.test(source)) return "bricklink_xml";
  const head = (source.split(/\r?\n/)[0] || "").toLowerCase();
  if (/(^|,)"?number"?(,|$)/.test(head) && /qtyowned|(^|,)"?own"?(,|$)|(^|,)"?want"?(,|$)|setid/.test(head)) return "brickset_csv";
  return "rebrickable_csv";
}
