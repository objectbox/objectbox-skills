# ObjectBox Sync Server — setup

Binding-agnostic. The server takes the generated model file; only the path you
copy it *from* differs per binding.

Official Sync docs: https://sync.objectbox.io/llms.txt — append `.md` to any
page URL for Markdown.

## The rule that catches most people

The server does **not** find the model by itself. You must do **both**:

1. mount a folder containing the model file to `/data`, and
2. start the server with `--model` pointing at that file.

Mounting the model somewhere without setting `--model` is the single most
common setup error — the server starts, and then fails on the first schema it
does not recognize.

## Setup

**1. Create a folder for the server dataset:**

```
./sync-server/
```

**2. Copy the generated model file into it, renamed to `objectbox-model.json`:**

| Binding | Copy from |
|---|---|
| Java/Kotlin | `objectbox-models/default.json` |
| Swift | `model-<project-name>.json` |
| Dart, Go, C/C++ | `objectbox-model.json` |

**3. `docker-compose.yml`:**

```yaml
services:
  sync:
    image: objectboxio/sync-server-trial
    ports:
      # Use ports that are unique to this project — see "Isolation" below.
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

The dataset lives under `./sync-server/objectbox/`. To reset it, delete that
directory and restart.

## After every schema change

A stale server model produces errors that look like schema bugs — for example
`"Relations not allowed"`.

1. Run code generation for your binding.
2. Copy the regenerated model file to `./sync-server/objectbox-model.json`.
3. Wipe the server dataset: `rm -rf sync-server/objectbox/`
4. Restart the server.

## Isolation between projects

Give every project its own `./sync-server/` folder **and its own host ports.**
Sharing one server instance or dataset across projects means one project's
schema silently reaches another, and a wrong port connects you to the wrong
dataset without any error.

## Authentication

- **`--unsecured-no-authentication` is for single-machine loopback development
  only.** Never on a LAN or a public interface — anyone who can reach the port
  can read and write the whole dataset.
- **For anything else** — demos, multi-device, production — configure a shared
  secret via a JSON config file (`-c /path/to/conf.json` with
  `{"auth":{"sharedSecret":"..."}}`) and have the client authenticate with the
  shared-secret credentials form for its binding.
- Never commit the secret. Inject it from the environment or a secret store.
