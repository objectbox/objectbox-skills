# ObjectBox — Python

Binding-specific guidance for ObjectBox in Python (packages `objectbox` and `objectbox-sync`, version 5.0).
It assumes the binding-agnostic contract in [SKILL.md](../SKILL.md).
The Python binding has a smaller feature set than the other bindings:
to-one relations only (as plain integer IDs) and no data observers.
Where that conflicts with the contract, the sections below say what to do instead.

## Before you write code

1. **Check the installed version.**
   `python -c "import objectbox; print(objectbox.version_info())"` prints the binding and native library versions.
   Since 5.0, the Python code is in the package `objectbox-api`;
   `objectbox` and `objectbox-sync` contain no code and install it together with the native library
   (`objectbox-clib`, one wheel per platform, or its Sync variant `objectbox-sync-clib`).
   So for a Sync installation, `pip show objectbox` finds nothing: use `pip show objectbox-api`.
2. **Upgrading from 4.x with pip: uninstall first.**
   Run `pip uninstall objectbox`, then `pip install objectbox` (or `objectbox-sync`).
   An in-place `pip install --upgrade objectbox` breaks the installation:
   `import objectbox` then fails,
   e.g. with `ImportError: cannot import name 'Store' from 'objectbox' (unknown location)`,
   and running the upgrade again does not fix it.
   Repair it with `pip install --force-reinstall --no-deps objectbox-api`.
   Fresh installs and upgrades with uv are not affected.
3. **There is no code generation step.**
   The model is built at runtime from the `@Entity()` classes and synced into
   `objectbox-model.json` when a `Store` opens (see [Model file](#model-file)).
4. **Look up the API, don't recall it.** Any docs page can be fetched as Markdown by appending
   `.md`, e.g. https://docs.objectbox.io/getting-started.md (Python tab).
   The docs do not cover every Python API; the binding's docstrings and its examples do:
   https://github.com/objectbox/objectbox-python/tree/main/example.

## Entity declaration

```python
import os
from datetime import datetime, timezone
from objectbox import Entity, Id, String, Int64, Date, Index, IndexType, Store

@Entity()
class Task:
    id = Id
    text = String(index=Index(IndexType.VALUE))  # value index: queried with starts_with() below
    priority = Int64
    created = Date(py_type=datetime)  # read back as a UTC datetime

MODEL_JSON = os.path.join(os.path.dirname(os.path.abspath(__file__)), "objectbox-model.json")
store = Store(directory="memory:skill-example", model_json_file=MODEL_JSON)  # see "Model file"
box = store.box(Task)
task_id = box.put(Task(text="Buy milk", priority=2, created=datetime.now(timezone.utc)))
assert box.get(task_id).text == "Buy milk"
```

`@Entity()` replaces the class with an entity wrapper; the name `Task` no longer refers to a type:

- **Keyword arguments only.** `Task(text="...")` works; `Task("...")` raises `TypeError`.
  An unknown keyword raises an exception naming the property.
- **No `isinstance(obj, Task)`.** It raises `TypeError: isinstance() arg 2 must be a type`.
  Compare `type(obj).__name__` if you must dispatch on the entity type.
- **The class needs a constructor without arguments.** `get()` and queries create objects by
  calling the class without arguments and then set the attributes.
  A custom `__init__(self)` runs on every read, so state it sets is not read from the database.

## None and null values

Python has `None`; ObjectBox Python stores it as null, but reads it back as the default.

- A property never assigned is stored as its type's default:
  `0`, `""`, `b""`, `[]`, and the epoch (`1970-01-01 00:00 UTC`) for a `Date(py_type=datetime)`.
- A property set to `None` is stored as null (left out of the stored object).
  `None` inside a vector or list still makes `put()` raise; `Flex` stores `None` as a value.
- Reading never returns `None` (except for `Flex`): a null, like any property missing from a stored
  object, reads back as the default above.
- Queries do see the difference: a null does not match `equals("")` or `equals(0)`.
  Use `is_null()` and `is_not_null()` for it:

```python
null_id = box.put(Task(text=None))
assert box.get(null_id).text == ""  # read back as the default
nulls = box.query(Task.text.is_null()).build().find_ids()  # contains null_id
empty = box.query(Task.text.equals("")).build().find_ids()  # does not
assert null_id in nulls and null_id not in empty
```

So after a read, "null", "not set" and "set to the default" look the same.
Where the difference matters in the application, persist it explicitly: a `Bool` flag,
or a sentinel value you document; or query it with `is_null()`.

## Dates

`Date` stores milliseconds, `DateNano` nanoseconds, since the Unix epoch.
What you assign is converted by its Python type, and the conversion does not look at magnitude:

| Assigned value | Stored as |
|---|---|
| `datetime` with a timezone | its instant, exactly |
| naive `datetime` | interpreted in the machine's **local** timezone |
| `float` | **seconds** (`time.time()`) |
| `int` | taken as is: **milliseconds** for `Date`, nanoseconds for `DateNano` |

The trap: `int(time.time())` is seconds, stored as milliseconds,
and silently reads back as a date in January 1970.
Use timezone-aware `datetime` values, `float` seconds, or `int` milliseconds on purpose.
`Date(py_type=datetime)` reads back as a UTC `datetime`;
`py_type=int` reads back milliseconds (`DateNano`: nanoseconds) and `py_type=float` seconds.
Query conditions take the same values as assignment, e.g. a timezone-aware `datetime`:

```python
since = datetime(2026, 1, 1, tzinfo=timezone.utc)
recent = box.query(Task.created.greater_or_equal(since)).build().find()
assert all(task.created >= since for task in recent)
```

## Relations

Python has to-one relations only: a `Relation` property holds the ID of an object of the target entity
as a plain `int` (0 for none).
There are no ToOne/ToMany objects and no to-many relations, and nothing is loaded for you;
link queries work as in Java and Dart:

```python
from objectbox import Entity, Id, String, Relation, Store

@Entity()
class Project:
    id = Id
    name = String

@Entity()
class Ticket:
    id = Id
    title = String
    project_id = Relation(Project)  # ID of a Project; 0 for none
    parent_id = Relation("Ticket")  # The entity itself, or one defined later: by name

relation_store = Store(directory="memory:skill-relations", model_json_file=MODEL_JSON)
project_id = relation_store.box(Project).put(Project(name="Apollo"))
relation_store.box(Ticket).put(Ticket(title="Launch", project_id=project_id))

qb = relation_store.box(Ticket).query()
qb.link(Ticket.project_id, Project.name.equals("Apollo"))  # Tickets of projects named "Apollo"
tickets = qb.build().find()
assert [ticket.title for ticket in tickets] == ["Launch"]

qb = relation_store.box(Project).query()
qb.backlink(Ticket.project_id, Ticket.title.starts_with("L"))  # Projects with a matching ticket
projects = qb.build().find()
assert [project.name for project in projects] == ["Apollo"]
```

Name a `Relation` like the relation with an `_id` suffix (`project_id`): it is stored as `projectId`,
exactly like the target ID of a `ToOne` named `project` in Java, Kotlin and Dart,
so a model file or Sync shared with them matches.
Assign the ID (`Ticket(title="...", project_id=project.id)`), query it with `Ticket.project_id.equals(project_id)`,
and load the target with `box.get()`.
ObjectBox knows the target, unlike with an `Int64` holding an ID:
removing a project resets `project_id` to 0 in its tickets, and the property is indexed.
A to-many relation is the reverse to-one: query the child entity by the parent's ID, or use `backlink()`.
`link()` and `backlink()` return the builder of the linked entity, to link further;
call `build()` and `order()` on the query's builder, which raises otherwise.
Results are objects of the query's entity only.
Still application code: removing dependent objects.
Do not generate ToOne/ToMany code from another binding's docs.

## Queries and lifecycle

```python
query = box.query(Task.text.starts_with("Buy") & Task.priority.greater_than(1)).build()
tasks = query.find()
count = query.count()
```

- Conditions combine with `&` and `|`; `query.offset(n).limit(m)` chain (both return the query).
- `find_first()` returns the first object (by ID, or by the query's `order()`) or `None`;
  `find_unique()` returns the only match or `None`, and raises `NonUniqueResultError` if there are more.
- **Short-lived queries: build, run, close in one scope.** `build()` closes the builder (it can not be used again);
  a `Query` is closed by `close()`, at the end of a `with` block, when garbage-collected, or when its store closes:

  ```python
  with box.query(Task.text.equals("Buy milk")).build() as one_off:
      first = one_off.find_first()
  ```

- **Hot paths: build a query once and reuse it.** Building costs more than running:
  a simple query built per call takes about twice as long as re-running a built one.
  Keep the built query and change its values with `set_parameter()` before re-running it:

  ```python
  query.set_parameter(Task.text, "Call")
  calls = query.find()
  ```

  The property's type decides what the value means, e.g. a list for a `one_of()` condition or the
  query vector of a nearest-neighbor search.
  `set_parameters(prop, a, b)` changes both values of `between()`.
  The typed 4.x methods (`set_parameter_string()`, `set_parameter_int()`, `set_parameter_vector_f32()`, ...)
  were removed in 5.0.

- Lifetime, threads and what to query instead of loading a box:
  the contract's [queries rule](../SKILL.md#4-queries).

## Unique values and object IDs

A natural key (an email, an ID from another system) is a unique property, not the object ID:

```python
from objectbox import Unique, UniqueViolatedError

@Entity()
class Customer:
    id = Id
    email = String(unique=Unique())  # indexed (a hash index by default for strings)

customer_store = Store(directory="memory:skill-unique", model_json_file=MODEL_JSON)
customers = customer_store.box(Customer)
customers.put(Customer(email="ann@example.com"))
try:
    customers.put(Customer(email="ann@example.com"))
    raise AssertionError("expected UniqueViolatedError")
except UniqueViolatedError:
    pass  # nothing was put
by_email = customers.query(Customer.email.equals("")).build()  # built once, re-run per lookup
assert by_email.set_parameter(Customer.email, "ann@example.com").find_unique() is not None
customer_store.close()
```

- `Unique(ConflictStrategy.REPLACE)` removes the existing object instead of raising;
  only one property per entity can use it, and Sync entities need it on all unique properties.
- Object IDs are assigned by ObjectBox. Putting an object with an ID that ObjectBox did not assign
  raises `IllegalArgumentError` ("ID is higher or equal to internal ID sequence").
  `Id(assignable=True)` accepts your own IDs; new objects (ID 0) then get IDs above the highest one put.

## Transactions and batching

Every `put()` or `remove()` outside a transaction is its own write transaction,
and each commit waits for the disk sync (milliseconds on typical SSDs).
Writing many objects one by one is therefore dominated by syncs.

```python
tasks = [Task(text=f"Task {i}") for i in range(1000)]
ids = box.put(tasks)  # one transaction; returns the IDs, which are also set on the objects
assert ids[0] == tasks[0].id > 0
assert box.remove_many(ids[:10]) == 10  # one transaction; returns the number removed

with store.write_tx():  # several operations, one commit
    box.put(Task(text="first"))
    box.put(Task(text="second"))
```

A `write_tx()` block commits when it ends normally and rolls back on any exception,
including `KeyboardInterrupt`.

## Reactive updates

There is no data observer or query subscription API in the Python binding.
The contract's [reactive rule](../SKILL.md#5-reactive-updates) cannot be met with ObjectBox alone:
signal changes in the application (the code path that writes also notifies),
and if a process must detect writes of another process, say explicitly that it polls and why.
Changes received by Sync are the exception: see [Sync](#sync).

## Vector search (HNSW)

Score is a **distance** — lower is better.
`find_with_scores()` returns `ObjectWithScore` named tuples (`.object`, `.score`), `find_ids_with_scores()`
`IdWithScore` (`.id`, `.score`); both unpack as `for obj, score in ...`.
The method names and the parameter API are in
[vector-search.md](vector-search.md#per-binding-api--do-not-extrapolate).
`Float32Vector` properties read back as `numpy.ndarray`, so vector properties need numpy;
entities without vector or flex properties do not, and `import objectbox` does not import numpy.

## Sync

Sync needs the Sync variant of the native library:
install the package `objectbox-sync` **instead of** `objectbox` (it provides the same module `objectbox`).
With `objectbox`, `Sync.is_available()` returns `False` and `Sync.client()` raises `FeatureNotAvailableError`.

```python
from objectbox import Entity, Id, String, Store, Sync, SyncClock, SyncCredentials, SyncEntity

@SyncEntity()
@Entity()
class Message:
    id = Id
    text = String
    sync_clock = SyncClock  # conflict resolution: the last write wins

sync_store = Store(directory="memory:skill-sync", model_json_file=MODEL_JSON)
client = Sync.client(sync_store, "ws://127.0.0.1:9999", SyncCredentials.none())
client.start()  # connects and syncs in the background, also offline
sync_store.box(Message).put(Message(text="synced"))
sync_store.close()  # closes the client first
```

- **`@SyncEntity()` objects are writable only while a Sync client is started for the store.**
  Before `client.start()`, or without a client, `put()` raises `IllegalStateError`
  ("sync has not been activated for this store").
  The client does not need a reachable server.
  Plain `@Entity()` classes in the same store are local-only and always writable.
- One client per store: a second `Sync.client()` raises `IllegalStateError` until the first is closed.
  The store keeps its client alive (`store.sync_client()`) and closes it when the store closes,
  so the contract's [shutdown order](../SKILL.md#7-sync) is handled.
- Sync sends and receives automatically once started; do not add a fetch loop.
  Listeners (`set_change_listener()`, `set_login_listener()`, `set_connection_listener()`, ...)
  are called from the client's background thread: return quickly, and never close the client in one.
- `SyncCredentials.none()` pairs with a server started without authentication, for local development only;
  see [sync-server-setup.md](sync-server-setup.md).
- The model must match the server's by UIDs; see [Model file](#model-file) for names.

## Model file

`objectbox-model.json` holds the IDs and UIDs of entities and properties;
commit it (contract [rule 8](../SKILL.md#8-schema-and-the-model-file)).
It is read and rewritten whenever a `Store` opens with a model.

**Pass `model_json_file` explicitly.**
Without it, the file is placed next to the module that calls `Store(...)`, found via the call stack.
If a helper in `lib/db.py` opens the store, the file lands in `lib/`;
a store opened from another module (a test, a script) gets a different, fresh file,
whose new IDs do not match the existing database.

```python
import os
from objectbox import Store

MODEL_JSON = os.path.join(os.path.dirname(os.path.abspath(__file__)), "objectbox-model.json")
store = Store(directory="memory:skill-model-file", model_json_file=MODEL_JSON)
```

**Renames need the UID.**
Properties and entities are matched by UID first, then by name.
Renaming a property in the class makes it a new, empty property:
the old values are dropped silently, and reads return the default.
Look up the UID in `objectbox-model.json` and pass it:

```python
from objectbox import Entity, Id, String

@Entity()
class Note:
    id = Id
    title = String(uid=4630871347839405127)  # was "name"; UID from objectbox-model.json
```

For entities, use `@Entity(uid=...)`.

**Stored names are camelCase.**
Since 5.0, a property `date_created` is named `dateCreated` in `objectbox-model.json` and the database,
like in the other bindings; Python code keeps using the attribute names.
Everything outside Python sees the camelCase names:
the ObjectBox Admin, Sync filters, and documents in MongoDB (via Sync).
`@Entity(python_names=True)` stores the names as written in Python.
When an app moves from 4.x, model sync renames the stored names to camelCase and keeps the data;
commit the rewritten `objectbox-model.json`.
A model file from another binding or a Sync server matches by these names,
so a Python client can start from the server's model file.

**Many stores in one process** (e.g. one per user): the model is synced with the JSON file
once per process and `Model`;
to open an existing store with the schema stored in it, pass `skip_model_sync=True`
(new stores are still created with the model).

## Testing

- `directory="memory:<name>"` opens an in-memory store: no files, nothing to clean up.
- Pass a `model_json_file` in a temporary directory, or the committed one;
  never let tests create model files next to test modules by accident.
- Close stores (`store.close()`) at the end of each test.
- Tests that write `@SyncEntity()` objects need `objectbox-sync` and a started client;
  without a server, an unreachable URL is enough:
  `Sync.client(store, "ws://127.0.0.1:1", SyncCredentials.none()).start()`.
  This is for tests only: in the app, a started client keeps trying to connect.

## Quick reference — common mistakes

| Mistake | Why it breaks | Fix |
|---|---|---|
| `pip install --upgrade objectbox` from 4.x | pip removes the old files after installing the new ones: `import objectbox` fails, and upgrading again does not fix it | `pip uninstall objectbox` first; repair with `pip install --force-reinstall --no-deps objectbox-api` |
| `pip install objectbox` for an app using Sync | its native library has no Sync: `Sync.client()` raises `FeatureNotAvailableError` | install `objectbox-sync` instead of `objectbox` |
| putting a `@SyncEntity()` object before `client.start()` | raises `IllegalStateError`: "sync has not been activated for this store" | start the client first (no server needed); keep local-only data in plain `@Entity()` classes |
| snake_case names outside Python code, e.g. in Sync filters or MongoDB | stored names are camelCase since 5.0: `date_created` is `dateCreated` | use the camelCase name, or `@Entity(python_names=True)` |
| `Store(...)` without `model_json_file` | the model file lands next to whichever module calls `Store()`; another caller gets a fresh file with new IDs | pass `model_json_file` explicitly and commit the file |
| renaming a property or entity in the class | matched by name without its UID, it becomes new and empty; the old values are dropped silently | pass `uid=` from `objectbox-model.json` |
| expecting `None` back after putting `None` | a null reads back as the default: `0`, `""` or the epoch | query with `is_null()`, or persist "not set" explicitly, e.g. a `Bool` flag |
| `equals("")` or `equals(0)` to find values put as `None` | a null is not the default value: it does not match | `is_null()`, or `is_null() \| equals("")` for both |
| `int(time.time())` into a `Date` | an `int` is taken as milliseconds: the date reads back in January 1970 | assign a timezone-aware `datetime`, or `float` seconds |
| naive `datetime` into a `Date` | interpreted in the machine's local timezone | use timezone-aware `datetime` values |
| `isinstance(obj, Task)` or `Task("text")` | `@Entity()` returns a wrapper, not the class; both raise `TypeError` | keyword arguments only; no `isinstance` with entities |
| an entity `__init__` with required arguments | reads create objects by calling the class without arguments | keep a constructor without arguments |
| `box.query(...).build()` on every call | building costs about as much as running a simple query again: roughly twice the time per call | build once, re-run with `set_parameter()` |
| `set_parameter_string()` and other typed 4.x setters | removed in 5.0: `AttributeError` | `query.set_parameter(prop, value)` |
| a natural key as the object ID, e.g. `Customer(id=external_id)` | raises `IllegalArgumentError`: the ID was not assigned by ObjectBox | a `Unique()` property for the key, looked up with `find_unique()`; `Id(assignable=True)` only for IDs that really come from elsewhere |
| one `put()` per object in a loop | one commit and disk sync per object | `box.put(list)` or one `store.write_tx()` |
| an indexed `Int64` holding another object's ID | not a relation: removing the target leaves a dangling ID | `Relation(Target)` |
| ToOne/ToMany or observer code from another binding | Python has none: a `Relation` is a plain `int` ID; no relation objects or observers | `Relation(Target)` IDs and queries on them; notify from the writing code |
