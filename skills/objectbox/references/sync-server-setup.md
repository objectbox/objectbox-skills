# ObjectBox Sync Server — setup

Binding-agnostic. The server takes the generated model file; only the path you
copy it *from* differs per binding.

Official Sync docs: https://sync.objectbox.io/llms.txt — append `.md` to any
page URL for Markdown.

## The model file rule

The server needs your generated model file. It picks up a file named
`objectbox-model.json` from its working directory automatically; passing
`--model <path>` makes the choice explicit and is recommended — it fails
loudly instead of running with a stale or missing model. A server without your
current model rejects client logins with `UNSUPPORTED_DATA_MODEL` (error 57).

## Setup

**1. Create a folder for the server dataset:**

```
./sync-server/
```

**2. Copy the generated model file into it, renamed to `objectbox-model.json`:**

| Binding | Copy from |
|---|---|
| Java/Kotlin | `objectbox-models/default.json` |
| Swift | `model-<target-name>.json` |
| Dart | `lib/objectbox-model.json` |
| Go, C/C++ | `objectbox-model.json` |

**3. `docker-compose.yml`:**

```yaml
services:
  sync:
    image: objectboxio/sync-server-trial
    # Without a matching user the server may fail to create /data/objectbox.
    user: "${UID:-1000}"
    ports:
      # Use ports that are unique to this project — see "Isolation" below.
      # 127.0.0.1 binding reaches local clients only. Android emulators reach
      # the host as 10.0.2.2 — for emulator/device testing bind wider AND
      # switch to real authentication first.
      - "127.0.0.1:9999:9999"   # Sync endpoint
      - "127.0.0.1:9980:9980"   # Admin UI
    volumes:
      - ./sync-server:/data
    command:
      - --model
      - /data/objectbox-model.json
      # DEVELOPMENT ONLY — see "Authentication" below.
      - --unsecured-no-authentication
      - --admin-bind
      - 0.0.0.0:9980
```

**4. Start:** `docker compose up`

**5. Activate the trial:** open the Admin UI at `http://127.0.0.1:9980`,
accept the Sync Trial consent and log in with an ObjectBox account. The trial
runs **30 days per dataset** — the compose file alone does not give you a
working server.

**Smoke test:** `http://127.0.0.1:9980` serves the Admin UI, and
`http://127.0.0.1:9999` answers with a plain-text response from the sync
endpoint.

The dataset lives under `./sync-server/objectbox/`. To reset it during
development, delete that directory and restart.

## After every schema change

1. Run code generation for your binding.
2. Give the server the new model: restart it with the updated
   `objectbox-model.json`, **or** upload the file through the Admin UI
   (Schema Versions). The server tracks schema versions and manages clients
   still on older ones — do **not** wipe the dataset for a schema change.
3. A client whose schema the server does not know is rejected with
   `UNSUPPORTED_DATA_MODEL` (error 57). That error means "update the server
   model", not "reset the database".

If clients connect but nothing syncs, inspect the model JSON: entity types you
expect to sync must carry `"flags": 2`.

## Isolation between projects

Give every project its own `./sync-server/` folder **and its own host ports.**
Sharing one server instance or dataset across projects means one project's
schema silently reaches another, and a wrong port connects you to the wrong
dataset without any error.

## Authentication

- **`--unsecured-no-authentication` is for single-machine loopback development
  only.** Never on a LAN or a public interface — anyone who can reach the port
  can read and write the whole dataset.
- **JWT is the primary authentication method** in the server docs
  (`auth.jwt` in the server config). The simplest self-contained alternative
  is a shared secret: a JSON config file (`-c sync-server-config.json` with
  `{"auth":{"sharedSecret":"..."}}`) paired with the shared-secret credentials
  form in the client binding.
- Never commit the secret. Inject it from the environment or a secret store.
- Prefer the JSON config file over CLI flags for anything beyond a toy setup;
  CLI flags override the file when both are given.

## Operations notes

- The server's transaction history grows without bound by default — set
  `historySizeMaxKb` / `historySizeTargetKb` for anything long-running.
- For verbose logs use `--log-level debug` (`--debug` is deprecated).
