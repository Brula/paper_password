# Architecture

A Phoenix app that generates printable password cards. One page, no accounts,
nothing stored.

## The idea

A card is a grid of characters with an emoji on every row and column. You print
it, keep it in your wallet, and pick a starting cell you'll remember, the whale
row or the key column, then read off as many characters as the site wants. The
card is the password manager; the emoji are how you find your place on it.

## The core

Everything that matters is `seed -> grid`, in `lib/paper_password/`:

| Module | Does |
| --- | --- |
| `Card` | Generates the grid, and reads a password out of it |
| `Card.Spec` | Grid dimensions and alphabets, versioned |
| `Card.Emoji` | The curated row and column labels, versioned |
| `Card.Id` | Card ID <-> seed, Crockford base32 with a check symbol |
| `Run` | Dealing and resizing the run of cards on the page |

**ChaCha20 keyed by the seed**, not `:rand`. The threat model is someone
photographing part of your card; a seeded LCG leaks its state to anyone holding
a run of its output, so they could reconstruct the rest from the piece they got.

**Rejection sampling** onto the alphabet. 256 is 62 x 4 + 8, so `rem(byte, 62)`
would hand the first eight characters five slots against the other 54's four,
25% more often, in every card ever made. Bytes landing in the incomplete final
window are discarded instead.

**Spec and emoji lists are a frozen format.** Change the grid dimensions, the
alphabets, or the emoji (including their order), and every card already printed
silently starts giving people the wrong passwords. Nothing crashes. Add a `v2`.
`test/paper_password/card_test.exs` has a "v1 format stability" block that pins
this down.

21 columns is odd on purpose: `read/5`'s diagonals only tour the whole grid
while the column count stays coprime with the 8 rows, so 20 columns would make a
diagonal password repeat after 40 characters instead of 168.

A card either has punctuation in it or it doesn't, and the top bit of the seed
says which. That keeps it out of the ID's grammar while still being covered by
the check symbol, so mistyping the flag is caught like any other typo instead of
silently reprinting the other alphabet. The bit next to it says whether the card
gives one row over to digits, for PINs. Which row comes off the front of the
same keystream, so it moves from card to card and a reprint still puts it back
where the paper has it.

Card IDs are Crockford base32 because they get hand-copied: it drops `I`, `L`,
`O` and `U` and folds the confusables back on decode. Every separator is
optional, the one after the version prefix included, because a person retyping a
code writes it as one run of characters as often as not.

## Alphabets

The 62-character alphabet keeps its confusables. Excluding `0`/`O` and `1`/`l`/`I`
would cost ~0.4 bits per character, and the mono font disambiguates them at
render time instead.

The symbols toggle adds sixteen: `!#$%&*+=?@^;<>()`. Every symbol on a US
keyboard was a candidate; these are the ones that survive the trip from printer
to login form.

- `"`, `'` and `` ` `` are out, being indistinguishable at 3.5mm, and they terminate
  strings in half the places a password gets pasted.
- `|` is out; against a mono `l`, `I` and `1` it is a coin flip.
- `-`, `_` and `~` are out: at this size all three are one horizontal stroke.
- Where two glyphs are a confusable *pair*, at most one gets in. `;` is here and
  `:` is not; `,` and `.` are both out, being the same speck; so are `/`/`\` and
  `[`/`{`.
- `(`/`)` and `<`/`>` are mirror images rather than lookalikes, so both halves of
  each pair are fine.

The wider alphabet buys little on its own: 78 characters instead of 62 is 6.29
bits a cell instead of 5.95, so a 12-character password goes from 71 to 75 bits.
It exists for the sites that reject a password for *not* containing a symbol.

## Labels

Rows are animals, columns are objects. Keeping the axes in disjoint categories
is what makes a cell sayable: "the octopus row, the guitar column" is
unambiguous in a way two mixed sets would not be. Four rules:

- **Single codepoint.** No ZWJ sequences, skin-tone or gender modifiers, or
  variation selectors, which render inconsistently and break naive slicing.
  The three BMP picks (`⌛` U+231B, `⭐` U+2B50, `⚡` U+26A1) are
  `Emoji_Presentation=Yes`, which is not enough on its own to get them drawn in
  colour: that property settles the default only where the renderer has a free
  choice, and font fallback gets there first. Under the grid's `font-mono` stack
  the browser found Menlo's outline glyph and stopped looking. The `[role="img"]`
  rule in `assets/css/card.css` is what actually decides it.
- **Unicode 6.0 or earlier**, or older phones and printer drivers show tofu.
  `🦙` U+1F999 is the one knowing exception, being Unicode 11.0. A row is the cheapest
  place to spend that: a row that tofus is still found by its colour band and its
  position, where a column that tofus has neither. Not a precedent for columns.
- **Distinct silhouette at small sizes.** A row label prints at 3.4mm and a
  column label at 2.8mm, which rules out most faces and anything round. Round
  glyphs (balloon, dartboard) collapse into the same blob, thin-stroke ones
  (bicycle) lose their strokes in print, and conceptual pairs (key/lock) invite
  mix-ups when read aloud.
- **Distinct dominant colour**, at least for the eight rows. The shape carries
  the same information, so the card still works in greyscale and for colourblind
  readers. Columns may repeat a hue (three greens and four yellows are
  deliberate) but never *adjacently*: a printed card put a red mushroom next to
  a rose gift box, and at 2.8mm two red blobs a hair apart read as one smear. The
  gift box lost its place to `⚡`, the only zigzag in the set.

Row tints are hand-picked rather than derived from the accent: a fixed
percentage of a light grey and of a dark slate produce wildly different visual
weights. All eight sit at roughly equal lightness, ordered so no two lookalikes
are neighbours; the greys, penguin and elephant, are kept apart.

## The web layer

`PaperPasswordWeb.HomeLive` at `/` is the whole application: it generates a card
on mount, reloads one from a pasted ID, and lets you click a cell to preview
what reading from it gives you. It is the only page; LiveDashboard is mounted at
`/dev/dashboard` in dev.

The page holds a *run* rather than a card, because printing is the point and a
printer's unit of work is a sheet. Cards are dealt when the count changes rather
than at print time, so what the print dialog shows is what prints.

A run of more than one card is a stack of the real cards, and it splits around
whichever one is selected: cards above it show their top edge, cards below show
their bottom, and the selected card is whole in between. A run opens on its last
card, so a fresh deck is fanned out above the one in front rather than hanging
below it. Click any peeking slice to bring that card up. So the size of the run
is something you see rather than count, and the bottom slices carry the card IDs
for free.

Two things make it work without knowing how tall a card is. The slices are
`overflow: hidden` on a fixed-height slot, so the same rule fits the 8-row
wallet card and the 21-row phone card at any type size. And the painting order
is per card from `PaperPasswordWeb.Stack.depth/3` rather than document order,
because a stack has one card in front and the run has to be drawn outwards from
it, and document order can only draw front to back.

Printing undoes all of it: the clip, the absolute positioning and the stacking
order all reset, so the whole run prints however far the stack was flipped. The
phone view never stacks: a phone screen holds about one 21-row card, so edges
under it would be all a scroll ever reached.

The selection survives a flip on purpose. Reading the same cell on the next
card is the most direct demonstration that these are different cards and not
copies.

Picking a cell also dims the run of cells the password comes out of, which is
the part that teaches you what "read across from there" means. Those come from
`Card.trail/5`, the same walk `read/5` uses, handed back as coordinates instead
of characters, so the marks and the password cannot drift apart. None of it
prints: on paper it would be a marked path to somebody's password.

The card ID travels over the LiveView socket, never a query string, so the one
secret that reconstructs a grid stays out of access logs and `Referer` headers.

## Two formats

A card is drawn either as a wallet card to print or as a portrait card for a
phone screen. Both are views of the same grid: switching never redeals, and the
cell coordinates are the card's, not the view's, so `select_cell` and the reader
don't know which one is on screen.

Portrait means transposed: 21 object rows down, 8 animal columns across. 21
columns across a 375px phone is 17px a column; 8 is 40px. The colour bands move
with the animals onto the columns, because a band exists to keep the eye on the
line it is reading and in portrait a password runs *down* one animal column.
That is also why the reading directions are relabelled per format. `:right`
walks the object axis either way, but in portrait that axis points down the
screen, so the arrow has to. The compass is the grid reflected about its main
diagonal; ↖ and ↘ are the two keys that survive unchanged.

The PNG is drawn in `assets/js/card_image.js` from the portrait table already in
the DOM, not from a second copy of the grid shipped over the socket: one source
for the characters means the image cannot disagree with what was on screen. It
is canvas-only and never uploaded, and it is always drawn light, for the same
reason print is.

## Printing

The print rules live in `assets/css/print.css` and are more load-bearing than
they look. The card is laid out at true ID-1 size (85.6 x 53.98mm) so it fits a
wallet, with a height budget documented inline. The traps, all of which have
already been hit once:

- The card uses `min-height`, never a fixed `height`. A fixed height draws the
  border at 54mm and lets the grid run on underneath it.
- Column emoji are capped by column *width* (3.48mm), not the height budget, and
  what matters is the gap left over rather than the glyph: colour emoji fill
  their em box, so ink-to-ink spacing is column width less font size.
- Row emoji are capped the same way, against what the 6mm label column has left
  after the accent stripe and the padding, not against the row's height, which
  is generous. Sizing them against the height printed the animals on top of
  their own colour stripe.
- The column widths come from a `<colgroup>`, not from the first row. Under
  `table-layout: fixed` a width set on a `<th>` is ignored, which is how the
  label column silently ran at Tailwind's `w-8` (8.47mm) instead of 5mm and
  squeezed the object emoji to 0.36mm apart.

There is a **black and white** toggle for printers that have no colour to give.
It swaps the palette rather than removing it: white and a ~17% grey,
alternating, with a black stripe, because a band still has a job to do once the
hue is gone. That grey is the number to touch if a printer draws the bands too
faintly or too heavily; it started at 7% and printed as a speckle, because a
laser dithers a tone that light almost out of existence. Both palettes leave
through the same `--row-tint` and `--row-accent`, so every rule that paints a
band keeps working without knowing which one it got.

It is the one toggle that does not deal a new card. Symbols and the PIN row
change which character is in a cell, so they have to; a colour does not.

## What isn't here

- **No accounts, no auth, no user data.** This app has nothing to log into.
- **No database.** Ecto, the Repo, Postgres and the migrations are gone;
  nothing about a card is written down anywhere, so there was nothing to store.
  The app boots with no external services.
- **No mailer.** Swoosh and Finch went with the accounts that used them.
- **No i18n.** Gettext is gone. Every string in the app is in one of two places
  (`HomeLive`'s markup or `Card.Emoji`'s label names), and the emoji names are
  read aloud to find a row, so translating them would repoint every card.
- **No component library.** The generated `CoreComponents` shipped modals,
  tables, forms and inputs for a page that has none of them. What survived is
  `PaperPasswordWeb.FlashComponents`, and only for the two banners that show
  when the socket drops.

The supervision tree is Telemetry, PubSub and the Endpoint. If you find yourself
adding a database back, check first whether the thing you want to persist is a
card; storing those defeats the point.
