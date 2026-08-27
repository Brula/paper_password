# Working on this project

A toy: generate a password card, print it, keep it in your wallet. Keep changes
small and the ceremony low.

## Before you finish

```sh
make check
```

Format, tests and `credo --strict`. All three should pass; that's the whole
gate.

## The one real rule

`PaperPassword.Card.Spec.v1/0` and the v1 lists in `PaperPassword.Card.Emoji` are
a **frozen format**, not implementation details. The grid dimensions, both
alphabets and the symbols that extend one of them, the two seed bits that pick
the alphabet and the digits-only PIN row, how that row's position is drawn, and
the row and column emoji (including their order) all decide which character a
person reads off a printed card.

Change any of them and every card already in someone's wallet silently becomes
wrong. Nothing crashes; the grid still generates and still looks right.

`test/paper_password/card_test.exs` has a "v1 format stability" block that pins
this down. If it fails, you changed the format: add a `v2` spec rather than
editing v1.

Nothing has shipped yet, so amending v1 is still free. That stops the moment
someone prints a card.

## Conventions

- Match the surrounding style.
- Add tests for new behaviour; the card logic is pure and cheap to test. The
  test name is the documentation; write it so no comment is needed.
- Comment only what would otherwise let someone break the code: a trap, an
  invariant a future edit would break silently, a contract imposed from outside.
  Everything else the names should carry.
- Design rationale goes in `ARCHITECTURE.md`, not in a comment. It is the map:
  read it before changing how anything fits together, and update it when you do.
  Argue a decision once; a story told twice drifts.
- Update `README.md` when the setup steps or the dependencies change.
- Commit when it makes sense. No mandatory push.
