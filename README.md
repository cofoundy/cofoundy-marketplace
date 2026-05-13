# cofoundy-marketplace

Catálogo de plugins de Cofoundy para Claude Code. Repo mínimo, solo `marketplace.json`.

## Por qué existe (y por qué es chico)

Antes este catálogo vivía dentro de `cofoundy-toolkit`. Cada vez que alguien agregaba el marketplace, Claude Code clonaba el toolkit entero (~40 MB, varios minutos en redes lentas → timeout). Separar el catálogo a su propio repo hace que `Add marketplace` clone <10 KB en <1s. Los plugins en sí siguen viviendo en sus repos individuales y se clonan solo cuando los instalas.

## Cómo agregarlo

```bash
# En Claude Code:
/plugin → Add marketplace → cofoundy/cofoundy-marketplace
```

O directamente en `~/.claude/settings.json`:

```json
{
  "enabledMarketplaces": [
    { "source": "github", "repo": "cofoundy/cofoundy-marketplace" }
  ]
}
```

Después aparecen los 6 plugins disponibles para instalar:

| Plugin | Audiencia | Repo |
|--------|-----------|------|
| `cofoundy-toolkit` | Todos | [cofoundy/cofoundy-toolkit](https://github.com/cofoundy/cofoundy-toolkit) |
| `cofoundy-business` | Founders + closers | [cofoundy/cofoundy-business](https://github.com/cofoundy/cofoundy-business) |
| `cofoundy-founders` | Founders | [cofoundy/cofoundy-founders](https://github.com/cofoundy/cofoundy-founders) |
| `cofoundy-meta` | Founders | [cofoundy/cofoundy-meta](https://github.com/cofoundy/cofoundy-meta) |
| `cofoundy-pms` | T3-PMgineer + Partner | [cofoundy/cofoundy-pms](https://github.com/cofoundy/cofoundy-pms) |
| `cofoundy-orchestrator` | Founders | [cofoundy/cofoundy-orchestrator](https://github.com/cofoundy/cofoundy-orchestrator) |

## Mantenimiento

Cuando agregas/quitas un plugin o bumpeas versión: editar `marketplace.json` aquí. Los repos individuales de cada plugin se mantienen aparte.

`metadata.version` aquí es la versión del catálogo (no de un plugin individual). Bump menor cuando cambia un puntero, mayor en cambios estructurales.
