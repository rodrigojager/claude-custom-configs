// Turns claude/settings.json (this setup, with its owner's paths) into the
// settings for the machine it is installed on: tool, cache and repo paths
// rewritten, and the Herdr hook kept only where Herdr is installed.
//
// node apply-settings.mjs --template <file> --out <file> --home <dir>
//   --tools <dir> --cache <dir> --repos <dir> [--herdr]
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const args = process.argv.slice(2);
const opt = name => {
  const at = args.indexOf(`--${name}`);
  return at === -1 ? undefined : args[at + 1];
};
const has = name => args.includes(`--${name}`);
for (const name of ["template", "out", "home", "tools", "cache", "repos"]) {
  if (!opt(name)) throw new Error(`missing --${name}`);
}

const settings = JSON.parse(readFileSync(opt("template"), "utf8"));
const slash = path => path.replace(/\\/g, "/");
const deja = slash(join(opt("tools"), "deja-vu", "deja.exe"));
const herdrHook = join(opt("home"), ".claude", "hooks", "herdr-agent-state.ps1");

settings.env = {
  ...settings.env,
  npm_config_cache: join(opt("cache"), "npm-cache"),
  PUPPETEER_CACHE_DIR: join(opt("cache"), "puppeteer"),
};

for (const [event, groups] of Object.entries(settings.hooks ?? {})) {
  const kept = [];
  for (const group of groups) {
    const hooks = [];
    for (const hook of group.hooks ?? []) {
      if (typeof hook.command !== "string") {
        hooks.push(hook);
      } else if (hook.command.includes("herdr-agent-state.ps1")) {
        if (has("herdr")) {
          hooks.push({ ...hook, command: hook.command.replace(/"[^"]*herdr-agent-state\.ps1"/, `"${herdrHook}"`) });
        }
      } else {
        hooks.push({ ...hook, command: hook.command.replace(/^\S*deja-vu[\\/]deja\.exe/, deja) });
      }
    }
    if (hooks.length > 0) kept.push({ ...group, hooks });
  }
  if (kept.length > 0) settings.hooks[event] = kept;
  else delete settings.hooks[event];
}

const roles = settings.extraKnownMarketplaces?.["claude-roles"];
if (roles?.source?.source === "directory") roles.source.path = join(opt("repos"), "claude-roles");

writeFileSync(opt("out"), JSON.stringify(settings, null, 2) + "\n");
