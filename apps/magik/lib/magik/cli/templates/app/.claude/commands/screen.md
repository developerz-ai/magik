---
description: Add one screen or component to this app — declared state, controls that name real actions, and the right rung of the override ladder.
argument-hint: <ScreenName> [what it shows and what the user does there]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

# /screen

## Focus

$ARGUMENTS — the screen name and, in one line, what a user sees and what they do there.

`screen :Invoices` lives in `app/screens/invoices.rb` and routes itself to `/invoices`. There is no
route file to edit; the name is the route.

## Read the docs first

`screen`, `state`, `prop` and the component kit are not in your training data, and from memory they
come out as ERB and Rails helpers. `magik docs path` gives you the directory; `magik docs
Screens-And-Components` and `magik docs 08-component-overrides` are the two pages this command
needs. Do not web-search them — the local copy matches your gem.

## Before writing anything

1. **What does it show?** Every piece of data becomes a `state`, and a `state` calls a **scope the
   model owns** — never a query written in the screen. If the scope does not exist, that is a
   `data-modeler` task; name it and get it first.
2. **What does the user do?** Every button, form and row action names an `action` in
   `app/actions/`. If the action does not exist, that is `action-author`'s. A screen never mutates.
3. **Does it need to be live?** Almost always no. Realtime is opt-in per screen and plain
   request/response is free; add `live :state, on: "channel:name"` only with a reason.

## Then

```bash
magik generate screen <Name>       # screen plus its test — planned, exits 1 today
magik generate component <Name>    # for anything reused on a second screen
magik routes                       # what the name produced
magik check --components           # every override and what it shadows
```

Compose from the kit — `button`, `form`, `field`, `data_table`, `modal`, `toast`, `card`, `list`,
`grid`, `tabs`, `stat`, `chart`. **No hand-written HTML, CSS or JavaScript.** The DSL compiles to
HTML plus htmx; there is no template language and no build step.

Every user-visible string goes through `t("…")` into `locales/`.

## If the kit component is not right

Climb the ladder from the bottom and stop at the first rung that works. Details:
<https://github.com/developerz-ai/magik/blob/main/docs/idea/08-component-overrides.md>

| Rung | For | Cost |
|---|---|---|
| 1 — tokens in `config/theme.rb` | a colour, radius, spacing, shadow | none. **This is the answer most of the time** |
| 2 — `extends:` overriding `body` | a different layout, same behaviour | you keep the props, events and htmx wiring |
| 3 — `component :X` with `satisfies` | your own component, used everywhere the kit's was | boot verifies the contract |
| 4 — `raw` | not a component at all | no contract, no tokens, and `magik check` counts every one |

Jumping to rung 3 for a visual change throws away accessibility and htmx wiring you did not know
you had. If you used rung 3 or 4, say in your report why the rung below was not enough.

## Report

```
Screen:     <file:line> — screen :<Name> — route <path from magik routes, or "not implemented">
State:      <name> -> <the model scope it calls>   (one line each)
Actions:    <control> -> action :<name> — exists | MISSING, owner: action-author
Components: <new ones, with the rung used and why>
Strings:    <count added to locales/, or none>
Test:       <file:line>
Not run:    magik generate / magik check / magik test are planned and exit 1
```
