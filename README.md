# Paper Password

Generate a printable password card. Keep it in your wallet, read your passwords
off it.

```
    🍕🌵🎸🔑🍄⚡🚀🍌🌻🎩🌲🍆⌛🔥🍺🌊💡🌈🎉⭐🍀
🐳  W C 4 C U 9 j Y L x z h K x 5 m e X R K z
🐝  5 q J n a k T n f C t f X S p G y M b K B
🐙  L j v B z g G J g I A L l T p L 5 r v d P
🦙  K 5 5 2 b L V j g 3 C 7 E w I P W X 4 j V
🐧  g 0 S u 2 u y 9 I Q r v Y r 4 O v V H w t
🐷  2 B A b v s O y Q 2 3 L i i Z F c E Y i U
🐢  L F z Q 4 k m D l l o o S D i K 6 w P M N
🐘  H K h H K v n f s 7 O p o z 2 f s u 5 1 M
```

Pick a cell you'll remember, 🐳 whale + 🔑 key for the bank, and read across
for as many characters as the site allows. Every cell can hold any character.

For the sites that demand punctuation, a toggle deals a card that also draws
from `!#$%&*+=?@^;<>()`. A second toggle gives one row over to digits, for PINs.
It lands on a different row on each card, so it isn't the one an onlooker
expects. Either one is a different card, ID and all; neither can be added to a
card already in your wallet.

Nothing is stored. There is no database, no account and no session. The card is
derived from its ID every time it is shown, so write the ID down somewhere
separate and you can reprint a lost card years later.

> **The ID *is* the card.** Anyone who has it can regenerate the whole grid, so
> it deserves the same care the printed card does. Keep it somewhere other than
> the card itself: lose both and the passwords are gone, lose the ID to someone
> else and so are they.

The card can also be drawn upright for a phone screen and saved as an image.
That is a real trade rather than a convenience: a card in your photo roll
syncs, backs up and unlocks with your phone, and paper does none of those
things. The app says so at the point you choose it.

## Running it

Needs Elixir and Erlang/OTP. Developed against Elixir 1.19 and OTP 28, and
`mix.exs` declares 1.15 as the floor, which is what Phoenix 1.8 asks for. No
database, no other services.

```sh
mix setup       # fetch deps, install and build assets
mix phx.server
```

Then http://localhost:4000.

```sh
make check    # mix format --check-formatted, mix test, mix credo --strict
```

## How it fits together

- [ARCHITECTURE.md](ARCHITECTURE.md): how a seed becomes a grid, why ChaCha20
  and rejection sampling, how the stack and the two card formats work, and the
  print geometry.
- [AGENTS.md](AGENTS.md): conventions, and the one change that breaks this
  project silently.

The short version: everything that matters is `seed -> grid` in
`lib/paper_password/`, and `PaperPasswordWeb.HomeLive` is the entire user
interface.

`PaperPassword.Card.Spec.v1/0` and the emoji lists in `PaperPassword.Card.Emoji`
are a **frozen format**. Change the grid dimensions, the alphabets, or the emoji
(including their order), and every card already printed silently starts giving
people the wrong passwords. Nothing crashes. Add a `v2` instead.

## License

MIT. See [LICENSE](LICENSE).

Reimplement it freely. A card is only recoverable by regenerating it from its
ID, so the more implementations that can do that, the better off anyone holding
one is. `test/paper_password/card_test.exs` has a "v1 format stability" block
with known seeds and grid hashes; those are the numbers to check a port
against.
