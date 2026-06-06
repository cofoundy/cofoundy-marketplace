# 2026-06-05 — Codex Compatibility Validation

**Operador:** Codex + Andre Pacheco

---

## Contexto

Andre pidió validar la capa de compatibilidad creada por Antigravity contra una sesión real de Codex. La expectativa operativa era que Codex, igual que Claude Code, supiera quién es el usuario, leyera el workspace brain de `~/cofoundy/CLAUDE.md`, y pudiera ejecutar el onboarding equivalente a `/workspace-setup`.

---

## Qué se validó

1. `codex plugin list` ve el marketplace `cofoundy` local y los 8 plugins instalados/enabled.
2. `uv run scripts/antigravity-harness.py list` lista correctamente skills y agent personas desde `.agents/plugins/` cuando se ejecuta fuera del sandbox read-only.
3. `codex debug prompt-input` confirma que el prompt model-visible de Codex incluye:
   - skills y plugins instalados;
   - `AGENTS.md` del repo actual (`cofoundy-marketplace`, symlink a `README.md`);
   - no incluye `~/.claude/CLAUDE.md`;
   - no incluye `~/cofoundy/CLAUDE.md`.
4. `~/.claude/CLAUDE.md` sí tiene identidad:
   - User's name: `André Pacheco`;
   - User's github: `A-PachecoT`;
   - User's role at Cofoundy: `CEO`.
5. `~/cofoundy/CLAUDE.md` existe y contiene la jerarquía de contexto workspace, pero `~/cofoundy/AGENTS.md` no existe.
6. Después de crear `~/cofoundy/AGENTS.md -> CLAUDE.md`, `codex debug prompt-input` desde `~/cofoundy` sí incluye el workspace brain.
7. Después de crear `AGENTS.md -> CLAUDE.md` en los 8 plugin source repos, `codex debug prompt-input` desde `~/cofoundy/plugins/cofoundy-toolkit` sí incluye el rulebook del plugin.

---

## Hallazgos

* **Plugin install funciona, context bootstrap no:** Codex cargó skills desde plugin cache, pero no cargó la identidad global ni reglas workspace. El problema no es marketplace install; es context injection.
* **`/workspace-setup` sigue siendo Claude Code-only:** vive en `commands/workspace-setup.md`, pero el manifest `.codex-plugin/plugin.json` solo expone `skills`; Codex no recibe comandos Claude-style como slash commands.
* **Identity Injection Pattern está acoplado a Claude:** `workspace-setup.md` y skills como `comms`, `deployment/local-pages.py` leen/escriben `~/.claude/CLAUDE.md`. Para Codex hace falta un reader multi-runtime o un mirror hacia `AGENTS.md`.
* **Falta workspace bridge:** Codex en `~/cofoundy/...` debería ver `~/cofoundy/AGENTS.md -> CLAUDE.md`. Hoy solo existe `~/cofoundy/CLAUDE.md`.
* **Git repo boundary:** Codex no carga el `AGENTS.md` parent del workspace cuando el cwd está dentro de un repo Git anidado como `~/cofoundy/plugins/cofoundy-toolkit`; solo carga el `AGENTS.md` del repo activo.
* **Source repo bridge faltaba:** los symlinks bajo `cofoundy-marketplace/.agents/plugins/<plugin>/AGENTS.md` ayudan a Antigravity/marketplace discovery, pero no ayudan cuando Codex se abre directamente en `~/cofoundy/plugins/<plugin>`.
* **Version drift:** `cofoundy-toolkit/.claude-plugin/plugin.json` está en `1.22.98`, pero `.codex-plugin/plugin.json` está en `1.22.90`; Codex instaló el cache `1.22.90`.

---

## Decisión recomendada

Crear una capa Codex-first en toolkit:

1. `workspace-setup` debe ser también skill o script ejecutable reusable, no solo command markdown de Claude Code.
2. `workspace-setup` debe escribir/mantener:
   - `~/.claude/CLAUDE.md` para Claude Code;
   - `~/cofoundy/AGENTS.md -> CLAUDE.md` para Codex/Antigravity workspace context;
   - `AGENTS.md -> CLAUDE.md` en cada repo source con `CLAUDE.md`, o un archivo `AGENTS.md` generado que combine workspace + repo cuando sea necesario;
   - opcionalmente un archivo de identidad neutral (`~/.config/cofoundy/identity.md` o JSON) que skills puedan leer.
3. Como Codex no carga parent workspace dentro de repos Git anidados, no basta con `~/cofoundy/AGENTS.md`; hace falta uno de:
   - generar `AGENTS.md` por repo con una sección workspace + sección repo;
   - confirmar soporte Codex para `SessionStart` `additionalContext` y usar un hook de bootstrap;
   - abrir Codex con cwd `~/cofoundy` cuando se necesite workspace context completo.
4. Skills deben leer identidad con helper multi-runtime: neutral identity file, fallback `~/.claude/CLAUDE.md`.
5. Marketplace/toolkit release debe bumppear `.codex-plugin/plugin.json` junto con `.claude-plugin/plugin.json` para evitar cache drift.

---

## Validación pendiente

Después del fix:

1. abrir sesión Codex desde `~/cofoundy/plugins/cofoundy-marketplace`;
2. correr `codex debug prompt-input`;
3. confirmar que aparece el `AGENTS.md` del repo actual;
4. confirmar por separado si el parent `~/cofoundy/AGENTS.md` aparece; en Codex 0.135.0 no aparece dentro de repo Git anidado;
5. confirmar que el bloque `Cofoundy Identity` está disponible sin leer archivos manualmente;
6. reinstalar o upgrade del plugin toolkit para que Codex use la versión nueva.
