# sbx mixins template

A starting point for building a **mixin kit** for [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`).

A *mixin* layers extra tools, environment variables, credentials, network rules,
and config files onto an **existing** sbx agent (`claude`, `codex`, `gemini`, …).
It does not define an agent of its own — that is a `kind: sandbox` kit. If you
want to add a capability ("give every agent long-term memory", "give every agent
a linter", "wire in a vector DB client") to whatever agent the user already runs,
a mixin is the right shape.

> Reference implementation: [`sbx-kits-mem0`](https://github.com/ajeetraina/sbx-kits-mem0)
> is a production mixin built from this same layout (adds the Mem0 memory layer).

## Layout

```
spec.yaml                 # the template — fill in every <PLACEHOLDER>
scripts/push-kit.sh       # validate + push to a registry as image tags
examples/ruff/spec.yaml   # a complete, no-secret mixin you can copy
LICENSE
```

## Quick start

1. **Clone and rename.** Copy `spec.yaml`, replace every `<PLACEHOLDER>`. Start from
   `examples/ruff/spec.yaml` if your tool needs no credentials.
2. **Validate locally.**
   ```console
   sbx kit validate .
   ```
3. **Try it without publishing** by layering the local directory onto an agent:
   ```console
   sbx run --kit ./ claude
   ```
4. **Publish** when it works:
   ```console
   DOCKERHUB_NAMESPACE=<you> KIT_NAME=<kit-name> ./scripts/push-kit.sh
   # then anyone can: sbx run --kit docker.io/<you>/<kit-name>:latest claude
   ```

## The spec, field by field

| Field | Required | What it's for |
|---|---|---|
| `schemaVersion` | ✅ | Always `"1"`. |
| `kind` | ✅ | `mixin` for this template. |
| `name` | ✅ | Machine id, kebab-case (`mem0`). |
| `displayName` / `description` | – | Shown in UIs / on the Hub page. |
| `network.allowedDomains` | – | Hosts the install + runtime may reach. Deny-by-default otherwise. |
| `environment.variables` | – | Static, **non-secret** config baked into the sandbox. |
| `environment.proxyManaged` | – | Names of vars whose secret values the proxy injects at runtime. |
| `commands.install` | – | Runs **once** at creation. Use `user: "1000"`. |
| `commands.initFiles` | – | Config files written at startup (`onlyIfMissing` keeps user edits). |
| `memory` / `agentContext` | – | Tells the agent the capability exists and how to call it. |

### Secrets: never hardcode

A mixin must not contain an API key. Instead:

1. Declare the env var name under `environment.proxyManaged`.
2. The user stores the value once: `sbx secret set -g <service>`.
3. The sbx proxy injects it into the sandbox at runtime (`sbx run` has no `-e` flag),
   so the key never enters the spec, the image, or the sandbox filesystem.

### The `memory` block matters

Installing a tool is not enough — the agent has to *know* it's there. The `memory`
block is appended to the agent's memory file (`CLAUDE.md` / `AGENTS.md`) so the
agent reaches for your tool. Keep it short and tell it the exact command to run.

> Newer sbx schemas name this field `agentContext`. If `sbx kit validate` rejects
> `memory`, rename it to `agentContext`.

## Variants (optional)

To ship the same mixin wired to different backends (as mem0 does with
`:dmr` / `:openai` / `:gemini`), drop one spec per variant under
`kits/<variant>/spec.yaml`. `scripts/push-kit.sh` auto-discovers them and pushes
each as its own image tag.

## Proving the mixin is actually inside the sandbox

Once you launch an agent with your kit, verify on independent layers (use `!`
shell escapes inside the agent session). The principle: check the package, then
the kit-only fingerprints (env vars + init files declared *only* in your spec),
then an end-to-end run.

```console
# 1. The package the kit installed is importable at the pinned version
!python3 -c "import <pkg>; print(<pkg>.__version__)"

# 2. The env vars the kit set are present (these exist only in your spec)
!env | grep -E '<YOUR_VAR>'

# 3. The init file the kit wrote exists
!cat /home/agent/.<tool>/config.<ext>

# 4. End-to-end: actually use the tool
!<one command that exercises the installed capability>
```

`#2` + `#3` are the distinguishing signature that the **mixin** (not a manual
install) wired things up, since both are declared only in `spec.yaml`. See the
mem0 repo's README §4 for a fully worked version of this proof.

## License

See [LICENSE](./LICENSE).
