# OneHit local API and MCP server

Lets scripts and AI agents on the same computer read and change OneHit's items.
There are two layers:

```
AI client ──stdio──▶ onehit-mcp.exe ──HTTP, 127.0.0.1──▶ OneHit (ItemStore)
                                                            ▲
                      your script ──HTTP, 127.0.0.1─────────┘
```

Both are off until you turn on **Settings → Automation → Allow connections**
(`"apiEnabled": true` in `config.json`). OneHit must be running.

## Connect an MCP client

`onehit-mcp.exe` sits next to `onehit.exe` in the release folder. It needs no
token or port: it finds them itself. Point your client at its full path.

Claude Code:

```powershell
claude mcp add onehit -- "C:\path\to\OneHit\onehit-mcp.exe"
```

Other clients, such as Claude Desktop:

```json
{
  "mcpServers": {
    "onehit": { "command": "C:\\path\\to\\OneHit\\onehit-mcp.exe" }
  }
}
```

| Tool | What it does |
| --- | --- |
| `list_items` | Every item in display order, plus the current local time |
| `create_item` | Adds an item behind the others; `pin` shows it at once |
| `update_item` | Changes the named fields of an item, including its countdown |
| `pin_item` | Shows an item in the strip |
| `delete_item` | Deletes an item for good |

The tools take the same fields as the HTTP routes below. When OneHit cannot be
reached, a tool returns an error telling the model what to ask you to do.

The server speaks MCP revision `2026-07-28` (stateless, `server/discover`) and,
through `initialize`, `2025-11-25`, `2025-06-18`, `2025-03-26` and `2024-11-05`.

## Call the API yourself

While the API is on, `%APPDATA%\dev.onehit\onehit\api.json` holds what you need:

```json
{ "port": 53124, "token": "…" }
```

The port and token change every time OneHit starts or the switch is turned on,
so read the file on each run:

```powershell
$api = Get-Content "$env:APPDATA\dev.onehit\onehit\api.json" | ConvertFrom-Json
$headers = @{ Authorization = "Bearer $($api.token)" }

Invoke-RestMethod "http://127.0.0.1:$($api.port)/v1/items" -Headers $headers

$body = @{ text = 'Stand up'; time = @{ seconds = 1500 } } | ConvertTo-Json
Invoke-RestMethod "http://127.0.0.1:$($api.port)/v1/items" -Method Post `
  -Headers $headers -ContentType 'application/json; charset=utf-8' `
  -Body ([Text.Encoding]::UTF8.GetBytes($body))
```

Every request needs `Authorization: Bearer <token>`. Bodies are UTF-8 JSON, up
to 1 MiB.

### Routes

| Route | Body | Success |
| --- | --- | --- |
| `GET /v1/items` | | `200` `{ "now", "items": [Item] }` |
| `POST /v1/items` | Create | `201` Item |
| `GET /v1/items/{id}` | | `200` Item |
| `PATCH /v1/items/{id}` | Update | `200` Item |
| `POST /v1/items/{id}/pin` | | `200` Item |
| `DELETE /v1/items/{id}` | | `204`, no body |

`now` is the local time with its offset, for working out how long until a clock
time: `"2026-11-06T14:30:00+08:00"`.

### Item

```json
{
  "id": "m3k2x9a1",
  "text": "Send the invoice",
  "icon": "receipt",
  "hasImage": false,
  "sunk": false,
  "detail": false,
  "pinned": true,
  "time": { "kind": "reminder", "state": "running", "remainingSeconds": 1500 }
}
```

`items` lists floating items first, then sunk ones, each in list order. `pinned`
marks the item the strip shows; at most one item has it. `time` is `null` when
the item has no countdown, and `state` is `running`, `paused` or `ended`.

### Create and Update

| Field | Type | Create | Update |
| --- | --- | --- | --- |
| `text` | non-blank string, trimmed | required | optional |
| `icon` | `notes` `mail` `groups` `book` `rocket` `receipt` `basket` `bolt` `call` `code` `event` `flag` `home` `idea` `link` `star` | optional | optional; removes any picture |
| `sunk` | boolean | optional | optional |
| `detail` | boolean | optional | optional |
| `pin` | boolean: show it in the strip now | optional | not accepted (use `/pin`) |
| `time` | object, below | optional | optional; `null` removes the countdown |

Fields left out stay as they are. `time` is also a partial update:

| Field | Type | Meaning |
| --- | --- | --- |
| `seconds` | integer, 1–43200 | Time left. Required when the item has no countdown; restarts one that ended |
| `kind` | `reminder` (default) or `timer` | A reminder runs until it ends; a timer runs only while its item is pinned |
| `state` | `running` or `paused` | Start or pause by hand; automatic timer rules then leave it. Repeating a state changes nothing |

### Errors

```json
{ "error": { "code": "bad_request", "message": "time.seconds must be…" } }
```

| Status | `code` | When |
| --- | --- | --- |
| 400 | `bad_request` | Bad JSON, a wrong value, or an unknown field |
| 401 | `unauthorized` | Missing or wrong token |
| 403 | `forbidden` | The request came from a web page |
| 404 | `not_found` | No such item or route |
| 405 | `method_not_allowed` | The route does not take that method |
| 409 | `conflict` | Starting or pausing the countdown of a sunk item, or one that has ended without new `seconds` |
| 413 | `payload_too_large` | The body is over 1 MiB |

A refused request changes nothing, even if some of its fields were valid.

## Design decisions

**New items don't take the strip.** The UI's `create` inserts at the top because
the user just asked for that item. A program did not, and taking the pinned slot
would change what the user is looking at and pause any automatic timer on the
old pinned item. Items go after the others unless the caller sets `pin`. This
follows the product principle of not interrupting.

**The same rules as the UI.** Every change goes through `ItemStore`, so it saves,
repaints and applies the Timer and Reminder rules like a click does. Where the UI
acts on a hand gesture the API offers the outcome instead: `state` is a target
rather than a toggle, because a retried toggle would undo itself.

**Strict input.** Unknown fields and out-of-range values are refused rather than
dropped or clamped. A caller, especially a model, learns of its mistake from the
error; `{"second": 60}` reporting success would leave it believing a countdown
was set.

**Off by default, loopback only.** Most users have no use for an open port. The
server binds `127.0.0.1` on a port the system picks, which avoids clashes and a
setting for them.

**Keeping web pages out.** A page in your browser can send requests to
`127.0.0.1`, so listening locally is not enough. The token stops it, since a page
cannot read `api.json`. Requests with an `Origin` header or a `Host` other than
loopback are also refused, which covers DNS rebinding, and no CORS header is ever
sent.

**What the token does not protect against.** Any program running as you can read
`api.json`, just as it can already edit `items.json`. The switch's hint says so.

**The token only lasts one run.** A stale `api.json` left by a crash holds a dead
token. Nothing has to clean up at exit: the bridge reports "not reachable" on a
refused connection, and the next start replaces or removes the file.

**A stdio bridge instead of MCP inside the app.** Stdio works with every MCP
client and needs no port or token in the client's config, which suits a port and
token that change. `onehit.exe` is a GUI program with no usable stdout, so the
bridge is a separate small program. It holds no state and rereads `api.json` for
each call, so it keeps working when the app restarts.

**A hand-written MCP layer.** The server needs five tools and no sessions,
resources or notifications. That is about 100 lines of JSON-RPC, and leaves the
bridge with no dependencies at all.

**Both MCP eras.** The `2026-07-28` revision removed `initialize`, while many
clients still use it. A client's first request selects the era: `initialize`
gets the older result shape, and a request with a version in `params._meta` gets
the newer one, with `resultType` and cache hints.

**Item text is data.** Items can hold text pasted from anywhere, and a tool result
is read by a model, so the server's instructions say that item text is not
instructions. This reduces prompt injection risk but cannot remove it; clients
should still ask before destructive tools, and `delete_item` is marked as one.

### Known limits

- **Last write wins.** If a program changes an item while you are typing in it,
  your text replaces the program's when you finish editing. There are no ETags,
  since the lost update is rare and small.
- **No images.** `hasImage` reports a picture, but the API cannot set one. Taking
  a file path or URL would let callers make OneHit read files or fetch addresses.
- **No events.** A program has to poll to learn that a countdown ended.
- **No window or settings control.** Showing the window takes the keyboard focus,
  and a settings route could switch the API's own protections.

## Build

`flutter build windows --release` also builds `onehit-mcp.exe` into the release
folder. On its own, from `mcp/`, which is a separate package because
`dart compile` refuses a package with build hooks, as the app's dependencies have:

```bash
dart pub get
```

```bash
dart compile exe bin/onehit_mcp.dart -o onehit-mcp.exe
```
