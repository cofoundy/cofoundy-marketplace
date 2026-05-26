# cofoundy-marketplace

Catálogo de plugins de Cofoundy para Claude Code. Este es el **punto de entrada** al ecosistema interno: instala el marketplace una vez, después instalas los plugins que tu rol necesite.

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

Cuando agregas/quitas un plugin o bumpeas versión: editar `marketplace.json` aquí + commit + push. Los repos individuales de cada plugin se mantienen aparte.

`metadata.version` aquí es la versión del catálogo (no de un plugin individual). Bump menor cuando cambia un puntero (ej. nueva versión de un plugin), mayor en cambios estructurales (agregar/remover un plugin, cambio de schema).

**Workflow para agregar un plugin nuevo a la org:**
1. Crear repo del plugin en `cofoundy/` (ej. `cofoundy-newplugin`).
2. Agregar entry en `marketplace.json` aquí con su `name`, `source`, `version`, `description`, `author`, `homepage`.
3. Bump `metadata.version` (menor).
4. Commit + push.
5. Equipo recibe update automáticamente si tiene auto-update activado en el marketplace.
