---
name: spec-authoring
description: Use this skill whenever authoring or updating the project specification during the Plan phase of the Phillips Inc Software Factory outer loop. Covers the required fields, what makes Done criteria testable versus vague, and the draft/approved status lifecycle. Trigger this any time the task is to produce a project spec, not just when the word "spec" appears explicitly.
---

# Spec Authoring

## When this applies

This skill applies during **Plan** -- the voice-driven conversation that
produces the spec before any repository exists. There is no checkout to
write into yet: the spec is drafted and held in a Claude doc for the
duration of Plan. `project-bootstrap` (the next outer-loop phase) commits
the approved spec into the newly created repo as `spec/SPEC.md`, alongside
any ADRs from `adr-authoring`. Your job here is producing that content --
the single canonical artifact every later stage (Bootstrap, Sequence,
Inner Plan, Inner Build, Inner Review) reads to know what "done" means.

## Required fields

Write exactly this structure -- do not add or rename top-level fields
without the human explicitly asking for a change to the template itself:

```
# SPEC.md

**Status:** draft | approved

## Purpose
One sentence. What problem does this build solve? If you need two
sentences, the scope is probably not yet well-defined enough to build.

## Inputs / Outputs
The contract. What comes in, what comes out. Be concrete about types
and shapes, not just names -- "a list of transactions" is not a contract;
"a list of {date, amount, category} objects" is closer.

## What we produce
One of: library | CLI | service | batch

## Where we persist
One of: stateless | file | DB

## Method
One of: rules | classical ML | LLM

## Done criteria
Observable behaviors the TDD unit tests will assert. Not "the feature
works" -- specific, checkable statements. See "Testable vs. vague" below.
```

## Testable vs. vague Done criteria

This is the part most likely to go wrong, and the part later stages
depend on most. A bad example and a good example, side by side:

**Vague (reject this):**
> "The parser correctly handles arithmetic expressions."

**Testable (write this instead):**
> - `parse("1 + 2")` returns an AST whose root is a `+` node with integer
>   leaves `1` and `2`
> - `parse("1 + 2 * 3")` respects operator precedence -- the `*` node is
>   nested under the `+` node's right child
> - `parse("(1 + 2) * 3")` respects parentheses -- the `+` node is nested
>   under the `*` node's left child
> - `parse("1 +")` raises a `ParseError` with a message identifying the
>   incomplete expression

The test: could someone who has never talked to you write a unit test
directly from this line, with no further clarification? If not, it's
not a Done criterion yet -- keep refining it.

## Status lifecycle

- Start every spec at `Status: draft`, in the Plan doc.
- Do not change to `Status: approved` until the human explicitly states
  in conversation that the spec is approved. A short reply, a "looks
  good", or silence is not approval.
- `Status: approved` is what `project-bootstrap` checks for before it
  will run -- Bootstrap reads this doc's final content and commits it
  into the new repo as `spec/SPEC.md`. Plan itself never writes to a
  repo; there isn't one yet.
- Once approved and committed by Bootstrap, the spec is treated as
  fixed. Any further change means the project re-enters Plan; a merged
  `spec/SPEC.md` is not edited in place downstream.

## Where this content goes

During Plan: held in the Claude doc for this conversation, nowhere
else. Once approved, `project-bootstrap` is responsible for writing it
to `spec/SPEC.md` at the repository root as part of its own commit --
this skill does not write any files itself.