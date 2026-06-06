# cofoundy-marketplace

Catálogo de plugins de Cofoundy para agentic harnesses. Este es el **punto de entrada** al ecosistema interno: instala el marketplace una vez, después instalas los plugins que tu rol necesite.

Hoy soporta Claude Code y está en migración activa para Codex. La meta del repo no es quedar amarrado a un runtime específico, sino servir como SSOT portable para cualquier harness agentic que Cofoundy adopte: Claude Code, Codex, Antigravity u otros.

Contratos actuales:

- Claude Code: `.claude-plugin/marketplace.json`
- Codex: `.agents/plugins/marketplace.json`
- Plugins fuente: repos `cofoundy/cofoundy-*` con manifests por runtime cuando haga falta (`.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`)

---

## Onboarding (nuevo miembro de Cofoundy)

**Pre-requisitos:**
- Acceso al GitHub org `cofoundy/` (te lo provisiona un Partner cuando entras al equipo — acepta los invites que te llegan al correo).
- GitHub CLI instalado (`gh --version` debe funcionar).
- **GitHub auth via SSH** (no HTTPS — los repos privados clonan más limpio así):
  ```bash
  mkdir -p ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts
  gh auth login -p ssh -h github.com -w
  ssh -T git@github.com   # debe responder "Hi <user>! You've successfully authenticated"
  ```
- Claude Code instalado.

Si la guía paso-a-paso amigable (con expected output de cada comando) te ayuda más: **[Guía de setup para contractors](https://docs.cofoundy.dev/team/cofoundy/contractor-setup)**.

**Pasos:**

1. **Abre cualquier sesión de Claude Code** — no importa en qué proyecto estés.
2. Escribe `/plugins`
3. Se abre la pestaña **Discover** por defecto. Presiona **Tab dos veces** para navegar a la sección **Marketplaces**.
4. Haz clic en **Add marketplace** y pega la URL del repo:
   ```
   https://github.com/cofoundy/cofoundy-marketplace.git
   ```
5. Vuelve a `/plugins` → **Tab dos veces** hasta **Marketplaces** → entra al marketplace **cofoundy**.
6. Selecciona `cofoundy-toolkit` y elige **Install for you** (primera opción). Es el plugin base que todos en Cofoundy necesitan.
7. Regresa al marketplace **cofoundy** → **Enable auto-update** para recibir updates automáticamente.
8. Escribe `/reload-plugins` para cargar el plugin recién instalado sin cerrar la sesión.
9. Escribe `/workspace-setup` — clona los repos del workspace según tu rol y provisiona las API keys.

Las API keys se provisionan automáticamente al iniciar sesión (requiere acceso a la org y al provisioner vault de Vaultwarden).

---

## Plugins disponibles

| Plugin | Audiencia | Descripción | Repo |
|--------|-----------|-------------|------|
| `cofoundy-toolkit` | **Todos** | Image gen, landing pages, voice transcription, browser, deployment, branding, comms, presentations, docs, dev commands | [cofoundy/cofoundy-toolkit](https://github.com/cofoundy/cofoundy-toolkit) |
| `cofoundy-business` | Founders + closers | Hormozi library, web diagnosis, AI visibility audits, content creation | [cofoundy/cofoundy-business](https://github.com/cofoundy/cofoundy-business) |
| `cofoundy-founders` | Founders | Billing automation, domain management (write), vault admin, key rotation | [cofoundy/cofoundy-founders](https://github.com/cofoundy/cofoundy-founders) |
| `cofoundy-meta` | Founders | Metacognition layer: prompt capture, pattern extraction, system design methodology | [cofoundy/cofoundy-meta](https://github.com/cofoundy/cofoundy-meta) |
| `cofoundy-pms` | T3-PMgineer + Partner | Sprints, dailies, debriefs, retros, project close (PM side) | [cofoundy/cofoundy-pms](https://github.com/cofoundy/cofoundy-pms) |
| `cofoundy-orchestrator` | Founders | AI-native PM substrate: `.cofoundy/` state, frontier resolver, bundle builder, scope enforcer, QA-driven iteration. Compone con `cofoundy-toolkit:sprint`. | [cofoundy/cofoundy-orchestrator](https://github.com/cofoundy/cofoundy-orchestrator) |

Para instalar plugins adicionales: `/plugins` → entra al marketplace **cofoundy** → selecciona el plugin → **Install for you**.

---

## Por qué este repo es chico

Antes el catálogo vivía dentro de `cofoundy-toolkit`. Cada vez que alguien agregaba el marketplace, Claude Code clonaba el toolkit entero (~40 MB, varios minutos en redes lentas → timeout). Separar el catálogo a su propio repo hace que `Add marketplace` clone <10 KB en <1s. Los plugins en sí siguen viviendo en sus repos individuales y se clonan solo cuando los instalas.

---

## Mantenimiento (founders)

Cuando editas, creas o borras una skill/command/agent/hook en un plugin Cofoundy, el agente debe correr:

```bash
bash ~/cofoundy/plugins/cofoundy-marketplace/scripts/update-plugin.sh <plugin-name>
```

Ese comando bumpea `plugin.meta.json`, regenera manifests, valida drift, refresca cache de Claude Code via `sync-plugin.sh` y refresca cache de Codex via `codex plugin add <plugin>@cofoundy`. Para una nueva capability pública usa `--bump minor`; para metadata-only sin cambio funcional usa `--bump none`.

Los manifests runtime son generados; no los edites a mano salvo que estés cambiando el generador.

Archivos de marketplace:

- Claude Code: `.claude-plugin/marketplace.json`
- Codex: `.agents/plugins/marketplace.json`

Para evitar drift entre runtimes si solo cambias metadata/generador:

```bash
python3 scripts/plugin-manifests.py generate
python3 scripts/plugin-manifests.py check
```

El source de metadata por plugin vive en `~/cofoundy/plugins/<plugin>/plugin.meta.json`. El generador actualiza:

- `<plugin>/.claude-plugin/plugin.json`
- `<plugin>/.codex-plugin/plugin.json`
- `.claude-plugin/marketplace.json`

El marketplace Codex local mantiene entradas path-only en `.agents/plugins/marketplace.json`; las versiones las toma de cada `.codex-plugin/plugin.json`.

Estrategia portable: [docs/portable-marketplace-strategy.md](docs/portable-marketplace-strategy.md).

`metadata.version` aquí es la versión del catálogo (no de un plugin individual). Bump menor cuando cambia un puntero (ej. nueva versión de un plugin), mayor en cambios estructurales (agregar/remover un plugin, cambio de schema).

**Workflow para agregar un plugin nuevo a la org:**
1. Crear repo del plugin en `cofoundy/` (ej. `cofoundy-newplugin`).
2. Agregar manifests mínimos del runtime si el repo aún no los tiene (`.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, etc.).
3. Agregar entry en los marketplace manifests correspondientes.
4. Crear `plugin.meta.json` o correr `python3 scripts/plugin-manifests.py init-meta <plugin>`.
5. Correr `bash scripts/update-plugin.sh <plugin> --bump minor`.
6. Revisar diff.
7. Commit + push.
8. Equipo recibe update automáticamente si tiene auto-update activado en el marketplace/runtime.
