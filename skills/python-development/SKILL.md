---
name: python-development
description: "Write production-grade Python in the house style: functional, imports at top, no classes for business logic or views, PEP 8, stdlib first. ONLY for Python work. Use when implementing or editing Python: Flask/Bottle routes, modules/ service functions, scripts, tests. Triggers: 'write the python', 'implement the backend', 'build the service layer', 'add the route', 'write the module', 'fix the python'. Do NOT trigger on: frontend/UI work (use frontend-design), or non-Python languages."
---

# Python Development

This skill implements **Python** work to a production bar. It carries the judgment calls that
`CLAUDE.md` bullets cannot: when a class is actually justified, where error handling belongs,
what to test, and which stdlib tool is the correct one.

For UI work use `frontend-design`. For non-Python code, follow the project's `CLAUDE.md`
directly.

> The CLAUDE.md simplicity rules apply in full here. Unlike aesthetic code, there is no
> category of Python where extra complexity buys you anything.

## Non-negotiable conventions

These are house style. They are not open for per-file reinterpretation.

- **Imports at the top of every file.** Never inside a function. The one real exception is a
  genuine circular-import break or a heavy optional dependency, and it carries a comment
  saying which.
- **Functional for business logic and views.** No classes. Pure functions in `modules/` that
  take `db` explicitly rather than reaching for a global.
- **No ORM.** Direct PyMongo calls.
- **Thin routes.** A handler parses the request, calls one `modules/` function, and
  renders or returns. Logic in a route handler is a bug.
- **4-space indent** in new files. When editing an existing file, match that file.
- **The project's venv**, never system `python`/`pip`. Read the project's `AGENTS.md` /
  `CLAUDE.md` for the path; do not guess it.

## When a class IS justified

"No classes" is about business logic and views, not a ban on the keyword. These are fine:

- A framework demands one (`flask-login` needs a `User(UserMixin)` wrapper; `Enum`;
  `unittest.TestCase`).
- A custom exception type: `class ConfigError(Exception): pass`.
- An immutable value object with behavior, where `dataclass(frozen=True)` genuinely beats a
  dict.

Everything else is a function. If you reach for a class to group functions that share
arguments, pass the arguments instead. If you reach for one to hold state between calls, the
state belongs in the caller or the database.

## Step 1: Read before writing

1. Read the project's `CLAUDE.md` / `AGENTS.md`. Venv path, stack, and any project-specific
   rules override this skill.
2. Read the files you are about to edit. Match their existing patterns, naming, and indent.
3. Look for an existing helper before writing a new one. A near-duplicate utility is worse
   than the import.

## Step 2: Pick the right tool

Stop at the first rung that holds.

- **Stdlib over a dependency.** `pathlib` over `os.path` for paths. `datetime` with explicit
  `timezone.utc`, never naive `datetime.now()` for anything stored or compared.
  `collections.defaultdict` / `Counter` over hand-rolled accumulation.
- **A context manager over manual cleanup.** Files, connections, locks, temp dirs. If you
  wrote `try/finally` to close something, `with` is what you meant.
- **f-strings** for interpolation. Not `%`, not `.format()`. The exception is logging, which
  takes `%s` args so the string is never built when the level is off:
  `log.info("loaded %s rows", n)`.
- **`logging` over `print`** in anything that is not a CLI writing to stdout on purpose.
- **A dict** for data that crosses a boundary (Mongo document, JSON payload). A
  `dataclass` for a fixed-shape record used in several places. A tuple for a 2-field return.
  Do not build a dataclass for a value used once.

## Step 3: Error handling

Simplicity rules stop at trust boundaries. Validate there, and only there.

- **Validate at the edge**: request payloads, query params, file contents, API responses,
  anything from a user or a third party. Inside your own module, trust your own callers.
- **Catch what you can act on.** A bare `except:` or a blanket `except Exception:` that logs
  and continues hides the bug you will be paged for. Catch the specific exception, or let it
  propagate.
- **Never swallow silently.** If you catch and continue, log at `warning` or above with the
  context needed to find it.
- **Fail loudly on programmer error.** A missing config key should crash at startup, not
  return `None` into the request path three hours later.
- **No error handling for impossible states.** If the branch cannot happen, do not write it.

## Step 4: Real footguns

Check for these specifically; they survive review because they look correct.

- **Mutable default arguments.** `def f(items=[])` shares one list across every call. Use
  `None` and build inside.
- **Late binding in loops.** A lambda or closure built in a loop captures the variable, not
  its value. Bind it as a default argument.
- **`dict` mutation while iterating.** Iterate over `list(d.items())` if you are changing `d`.
- **Float arithmetic on money.** Use integer minor units (sen, cents) or `Decimal`. Never
  `float` for a currency amount.
- **Naive datetimes.** Mixing tz-aware and naive raises at the worst moment. Store UTC.
- **Broad `str.strip()` assumptions on user input** without also validating length and
  charset before it reaches a query.
- **Secrets in code or logs.** Read from the environment. Never log a token, password, or
  full connection string.

## Step 5: Verify

Non-trivial logic leaves a runnable check behind. A branch, loop, parser, or money or
security calculation is non-trivial. A one-line rename is not.

- Run the project's real test command, discovered from `pyproject.toml` / `Makefile` /
  `AGENTS.md`. Do not guess the command.
- Test the edge: empty input, one item, the boundary value, the malformed payload. A test
  that only covers the happy path proves the happy path.
- **Fail first.** For a bug fix, run the reproduction and watch it fail before you fix it.
- Import the module you just wrote before claiming it works. A passing test file that never
  imported your change proves nothing.
- Check `git status --porcelain` before declaring done. Every file listed should be one you
  meant to touch.

## Rules

- Imports at top. Functional for logic and views. Thin routes. These are not negotiable.
- The project's `CLAUDE.md` / `AGENTS.md` wins over this skill wherever they disagree.
- Reuse before you write. Stdlib before a dependency. Never add a dependency for five lines.
- Validate at trust boundaries, nowhere else.
- No feature, abstraction, config flag, or error path that was not asked for.
- If you wrote 200 lines where 50 would do, rewrite it before handing off.
- State what you could not verify, and why, rather than describing it as working.
