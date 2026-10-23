# claude-custom-configs

Minha configuração do Claude Code (CLI, Windows): mods, status line, atalhos e
as ferramentas que eles usam. Credenciais e tokens não estão aqui: o
`~/.claude.json` fica de fora, e dele só a lista de servidores MCP foi extraída.

## Instalar igual (outra máquina ou outra pessoa)

Com Git for Windows, Node.js e Claude Code instalados, num PowerShell:

```powershell
irm https://raw.githubusercontent.com/rodrigojager/claude-custom-configs/main/install.ps1 | iex
```

Para ver antes o que ele faria, ou pôr ferramentas e caches em outro lugar
(o padrão é `~/.claude/tools` e `~/.claude/cache`):

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/rodrigojager/claude-custom-configs/main/install.ps1))) -DryRun
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/rodrigojager/claude-custom-configs/main/install.ps1))) -ToolsDir D:\tools -CacheDir D:\claude-cache
```

O que ele faz, nesta ordem:

1. Clona (ou atualiza) este repositório e o [claude-roles](https://github.com/rodrigojager/claude-roles) em `~/.claude/repos/`.
2. Guarda uma cópia de cada arquivo que vai substituir em `~/.claude/backups/setup-<data>/`.
3. Escreve o `settings.json` com os caminhos da máquina (`setup/apply-settings.mjs`);
   o hook do Herdr só entra se o Herdr estiver instalado.
4. Acrescenta o `Alt+R` ao `keybindings.json` e o bloco do zvec-grep ao `CLAUDE.md`,
   mantendo o que já houver neles; copia o layout do claude-hud e o wrapper da status line.
5. Instala os plugins: claude-hud, claude-mermaid, plannotator e roles.
6. Instala as ferramentas que faltarem: CLI do plannotator (instalador oficial),
   zvec-grep (npm) e deja-vu (última versão, com checksum conferido, no PATH do usuário).
7. Configura os MCPs: zvec_grep, deja e, se o wmux estiver instalado, wmux.

Depois: abrir um terminal novo, entrar no Claude Code (cada pessoa com a própria
conta) e rodar `deja index` para indexar as sessões antigas.

Vale revisar no `settings.json`: modelo `opus` com esforço `xhigh`,
`skipDangerousModePermissionPrompt: true` e a permissão já liberada para o zvec-grep.

## O que está aqui

| Arquivo | Vai para | O que é |
| --- | --- | --- |
| `claude/settings.json` | `~/.claude/settings.json` | Modelo e esforço, plugins e marketplaces, hooks (deja e Herdr), status line com `refreshInterval: 1`, caches do npm e do Puppeteer no D: |
| `claude/keybindings.json` | `~/.claude/keybindings.json` | `Alt+R` abre o `/role` |
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | Instruções globais do zvec-grep |
| `claude/plugins/claude-hud/config.json` | `~/.claude/plugins/claude-hud/config.json` | Layout do claude-hud (ordem, agrupamentos, elementos ligados) |
| `claude/mcp-servers.json` | (referência) | Servidores MCP do escopo do usuário |
| `herdr/config.toml` | `%APPDATA%\herdr\config.toml` | Herdr, com a linha `$model_info` do Claude |

Os caminhos nos arquivos são os da minha máquina; o `install.ps1` os reescreve.

## Peças instaladas

**Plugins** (os marketplaces já estão no `settings.json`):

```
/plugin install claude-hud@claude-hud
/plugin install claude-mermaid@claude-mermaid
/plugin install plannotator@plannotator
```

O `roles` é meu e é lido direto da cópia de trabalho, que fica em
`~/.claude/repos/` (o mesmo esquema do `~/.codex` do Codex). O `settings.json`
já declara esse marketplace local; para recriar a pasta:

```
git clone https://github.com/rodrigojager/claude-roles $HOME\.claude\repos\claude-roles
claude plugin marketplace add $HOME\.claude\repos\claude-roles
claude plugin install roles@claude-roles --scope user
```

Editando essa pasta, `/reload-plugins` aplica a mudança sem reinstalar.
Este repositório também mora em `~/.claude/repos/claude-custom-configs`.

- [claude-hud](https://github.com/jarrodwatts/claude-hud): status line.
- [claude-mermaid](https://github.com/veelenga/claude-mermaid): diagramas Mermaid com preview.
  Baixa Puppeteer e Chrome; o `env` do `settings.json` manda esses caches para `D:\claude-cache`.
- [plannotator](https://github.com/backnotprop/plannotator): revisão de planos e código no navegador.
  Precisa também do programa `plannotator` no PATH (instalador do próprio projeto),
  que cria as skills `plannotator*` em `~/.claude/skills`.
- [claude-roles](https://github.com/rodrigojager/claude-roles): roles profissionais (`/role`).

**Status line com a role:** o `statusLine` aponta para
`~/.claude/roles-mod/statusline.cmd`, o wrapper do claude-hud que vem no
claude-roles (pasta `statusline/`). Copie o conteúdo dessa pasta para
`~/.claude/roles-mod/`.

**Servidores MCP** (`claude/mcp-servers.json`):

```
claude mcp add -s user zvec_grep -- zg server --stdio
claude mcp add -s user deja -- cmd /c D:\tools\deja-vu\deja.exe mcp
claude mcp add -s user wmux -- node C:\Users\Rodrigo\AppData\Local\wmux\app-2.9.1\resources\mcp-bundle\index.js
```

- **zvec-grep** (`zg`, pacote npm `@zvec/zvec-grep` instalado globalmente): busca
  semântica no workspace. O `CLAUDE.md` traz as regras de uso, e a permissão
  `mcp__zvec_grep__*` já está liberada no `settings.json`.
- **deja-vu** (`deja` 0.23, binário em `D:\tools\deja-vu`, no PATH do usuário):
  busca nas sessões antigas de todos os agentes. O índice fica em
  `~\.cache\deja`, que é uma junction para `D:\claude-cache\deja`
  (`New-Item -ItemType Junction -Path $HOME\.cache\deja -Target D:\claude-cache\deja`).
  Os hooks do `settings.json` vêm de `deja install claude-auto`, que também cria
  `~/.claude/commands/deja.md` e a skill `deja-history`. Para ler o OpenCode ele
  precisa de um `sqlite3` com funções JSON (`D:\tools\sqlite`, à frente no PATH).
- **wmux**: servidor do app wmux.

**Herdr:** o hook `~/.claude/hooks/herdr-agent-state.ps1` é instalado e
atualizado pela integração do próprio Herdr com o Claude, por isso não está aqui.
A linha `claude = [...]` em `rows_by_agent` mostra o `$model_info` (modelo,
esforço e role) que o wrapper da status line envia.

## Notas

- O disco C: está quase cheio; caches e ferramentas grandes ficam no D:
  (`D:\claude-cache`, `D:\tools`).
- `refreshInterval: 1` faz a troca de role aparecer na hora na status line; o
  wrapper reaproveita a saída do claude-hud entre mensagens, então cada
  atualização custa só o arranque do Node.
