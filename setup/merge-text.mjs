// Adds this setup's pieces to files the person may already have, keeping theirs:
//   keybindings <template> <target>  merges each context's bindings (template wins per key)
//   claude-md   <template> <target>  puts the zvec-grep block in, replacing an older copy
import { existsSync, readFileSync, writeFileSync } from "node:fs";

const [mode, template, target] = process.argv.slice(2);
const mine = readFileSync(template, "utf8");
const theirs = existsSync(target) ? readFileSync(target, "utf8") : "";

if (mode === "keybindings") {
  const want = JSON.parse(mine);
  const have = theirs.trim() ? JSON.parse(theirs) : { bindings: [] };
  for (const block of want.bindings) {
    const same = have.bindings.find(one => one.context === block.context);
    if (same) same.bindings = { ...same.bindings, ...block.bindings };
    else have.bindings.push(block);
  }
  writeFileSync(target, JSON.stringify({ $schema: want.$schema, $docs: want.$docs, ...have }, null, 2) + "\n");
} else if (mode === "claude-md") {
  const START = "<!-- ZVEC_GREP_START -->";
  const END = "<!-- ZVEC_GREP_END -->";
  const block = mine.slice(mine.indexOf(START), mine.indexOf(END) + END.length);
  const from = theirs.indexOf(START);
  const to = theirs.indexOf(END);
  const next = from !== -1 && to > from
    ? theirs.slice(0, from) + block + theirs.slice(to + END.length)
    : (theirs.trimEnd() ? `${theirs.trimEnd()}\n\n` : "") + block + "\n";
  writeFileSync(target, next);
} else {
  throw new Error(`unknown mode ${mode}`);
}
