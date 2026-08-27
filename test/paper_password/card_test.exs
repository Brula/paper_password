defmodule PaperPassword.CardTest do
  use ExUnit.Case, async: true

  alias PaperPassword.Card
  alias PaperPassword.Card.Id
  alias PaperPassword.Card.Spec

  @spec_v1 Spec.v1()

  describe "new/1" do
    test "produces a grid matching the spec dimensions" do
      card = Card.new()

      assert length(card.grid) == @spec_v1.rows
      assert Enum.all?(card.grid, &(length(&1) == @spec_v1.cols))
      assert length(card.row_labels) == @spec_v1.rows
      assert length(card.col_labels) == @spec_v1.cols
    end

    test "gives every card a different grid" do
      grids = Enum.map(1..50, fn _ -> Card.new().grid end)

      assert length(Enum.uniq(grids)) == 50
    end

    test "draws every cell from the full alphabet" do
      # 50 cards, because any one card can miss a given character by chance.
      chars =
        1..50
        |> Enum.flat_map(fn _ -> List.flatten(Card.new().grid) end)
        |> MapSet.new()

      assert MapSet.equal?(chars, MapSet.new(Tuple.to_list(@spec_v1.alphabet)))
      assert Card.new().pin_row == nil
    end
  end

  describe "the PIN row" do
    test "turns exactly one row over to digits" do
      card = Card.new(pin_row: true)

      assert card.pin_row in 0..(@spec_v1.rows - 1)
      assert Enum.all?(Enum.at(card.grid, card.pin_row), &(&1 =~ ~r/^[0-9]$/))

      other_rows = List.delete_at(card.grid, card.pin_row)
      assert Enum.any?(List.flatten(other_rows), &(&1 =~ ~r/^[a-zA-Z]$/))
    end

    test "reaches every row, so an onlooker cannot guess where the digits are" do
      rows = Enum.map(1..200, fn _ -> Card.new(pin_row: true).pin_row end)

      assert MapSet.equal?(MapSet.new(rows), MapSet.new(0..(@spec_v1.rows - 1)))
    end

    test "stays digits on a card with symbols, because a PIN pad has no # key" do
      card = Card.new(symbols: true, pin_row: true)

      assert card.symbols
      assert Enum.all?(Enum.at(card.grid, card.pin_row), &(&1 =~ ~r/^[0-9]$/))
    end

    test "rides in the id, so a reprint puts the digits back in the same place" do
      card = Card.new(pin_row: true)

      assert {:ok, rebuilt} = Card.from_id(card.id)
      assert rebuilt.pin_row == card.pin_row
      assert rebuilt.grid == card.grid
    end

    test "mistyping the flag is caught like any other typo" do
      seed = :binary.copy(<<19>>, 10)
      pin_id = Id.encode(Spec.with_pin_row(seed, true), 1)
      plain_id = Id.encode(Spec.with_pin_row(seed, false), 1)

      refute String.at(pin_id, 3) == String.at(plain_id, 3)

      typo =
        pin_id
        |> String.graphemes()
        |> List.replace_at(3, String.at(plain_id, 3))
        |> Enum.join()

      assert Card.from_id(typo) == {:error, :bad_checksum}
    end

    test "asking for one changes the whole grid, not one row" do
      seed = :binary.copy(<<19>>, 10)

      {:ok, plain} = Card.from_id(Id.encode(Spec.with_pin_row(seed, false), 1))
      {:ok, pinned} = Card.from_id(Id.encode(Spec.with_pin_row(seed, true), 1))

      assert Enum.all?(0..7, fn row -> Enum.at(plain.grid, row) != Enum.at(pinned.grid, row) end)
    end
  end

  describe "from_id/1" do
    test "rebuilds an identical card from the id alone" do
      card = Card.new()

      assert {:ok, rebuilt} = Card.from_id(card.id)
      assert rebuilt.grid == card.grid
      assert rebuilt.id == card.id
    end

    test "accepts an id that was hand-copied sloppily" do
      card = Card.new()

      sloppy =
        card.id
        |> String.downcase()
        |> String.replace("-", " ")

      assert {:ok, rebuilt} = Card.from_id("  " <> sloppy <> "  ")
      assert rebuilt.grid == card.grid
      assert rebuilt.id == card.id
    end

    test "rejects a mistyped id rather than returning a different card" do
      card = Card.new()
      body = card.id |> String.replace("-", "") |> String.replace_prefix("V1", "")

      for position <- 0..(String.length(body) - 1),
          replacement <- ~w(0 1 2 3 4 5 6 7 8 9 A B C D E F G H J K M N P Q R S T V W X Y Z),
          String.at(body, position) != replacement do
        typo =
          "V1-" <>
            (body |> String.graphemes() |> List.replace_at(position, replacement) |> Enum.join())

        assert Card.from_id(typo) == {:error, :bad_checksum},
               "single-character typo at #{position} was not caught"
      end
    end

    test "accepts an id retyped as one run of characters" do
      card = Card.new()

      squashed = String.replace(card.id, "-", "")

      assert {:ok, rebuilt} = Card.from_id(squashed)
      assert rebuilt.id == card.id
      assert {:ok, ^rebuilt} = Card.from_id(String.downcase(squashed))
    end

    test "accepts an id whose first hyphen went missing but not the rest" do
      card = Card.new()

      assert {:ok, rebuilt} = Card.from_id(String.replace(card.id, "-", "", global: false))
      assert rebuilt.id == card.id
    end

    test "rejects malformed and unknown-version ids" do
      assert Card.from_id("nonsense") == {:error, :bad_format}
      assert Card.from_id("V1-TOO-SHORT") == {:error, :bad_format}
      assert Card.from_id("V9-ABCD-EFGH-1234-56789") == {:error, :unknown_version}
      assert Card.from_id("") == {:error, :bad_format}
    end

    test "rejects a squashed id that is the wrong length" do
      card = Card.new()

      squashed = String.replace(card.id, "-", "")

      # Version 0 does not exist.
      assert Card.from_id("V0" <> String.slice(squashed, 2..-1//1)) == {:error, :bad_format}
      assert Card.from_id(String.slice(squashed, 2..-1//1)) == {:error, :bad_format}
      assert Card.from_id(String.slice(card.id, 0..-2//1)) == {:error, :bad_format}
    end
  end

  describe "v1 format stability" do
    # These cards are in the wild. If this test fails, the format changed and
    # every printed card just became wrong. Add a v2 spec instead of editing v1.
    @seed :binary.copy(<<7>>, 10)

    test "a known seed still produces its known grid" do
      {:ok, card} = Card.from_id(Id.encode(@seed, 1))

      assert Enum.join(Enum.at(card.grid, 0)) == "WC4CU9jYLxzhKx5meXRKz"
      assert Enum.join(Enum.at(card.grid, 7)) == "HKhHKvnfs7Opoz2fsu51M"

      assert :sha256
             |> :crypto.hash(Enum.map(card.grid, &Enum.join/1))
             |> Base.encode16(case: :lower) ==
               "053768c339cbf9d313e76964dec58bf7eb6b1e01507d2e761adcc67359d1d510"
    end

    test "the same seed with the symbols flag set still produces its known grid" do
      {:ok, card} = Card.from_id(Id.encode(Spec.with_symbols(@seed, true), 1))

      assert card.symbols
      assert Enum.join(Enum.at(card.grid, 0)) == "K(&u3OEc52=)h#U=EBd!s"
      assert Enum.join(Enum.at(card.grid, 7)) == "><3c6qmPK5(k?wszh5lB@"

      assert :sha256
             |> :crypto.hash(Enum.map(card.grid, &Enum.join/1))
             |> Base.encode16(case: :lower) ==
               "a95bc2fa0de8e594ad57989a1a63dc7d7f67927b1f9638c43e437012d883e5b1"
    end

    test "the same seed with the PIN row flag set still produces its known grid" do
      {:ok, card} = Card.from_id(Id.encode(Spec.with_pin_row(@seed, true), 1))

      assert card.pin_row == 7
      assert Enum.join(Enum.at(card.grid, 7)) == "218436844588215601686"

      assert :sha256
             |> :crypto.hash(Enum.map(card.grid, &Enum.join/1))
             |> Base.encode16(case: :lower) ==
               "9410d3c59bef105f568e058b1c385ac6e8f056d1786465b9cd859b4f4db4be59"
    end

    test "the same seed with both flags set still produces its known grid" do
      seed = @seed |> Spec.with_symbols(true) |> Spec.with_pin_row(true)
      {:ok, card} = Card.from_id(Id.encode(seed, 1))

      assert card.symbols
      assert card.pin_row == 1

      assert :sha256
             |> :crypto.hash(Enum.map(card.grid, &Enum.join/1))
             |> Base.encode16(case: :lower) ==
               "ca1bd9bc971e60ad25f172e595c9fb21da24c5950fed6e8081b87d92076c24c6"
    end

    test "the symbols are still in their frozen order" do
      assert symbols() == ~w[! # $ % & * + = ? @ ^ ; < > ( )]
    end

    test "the column count stays coprime with the row count" do
      # An even `cols` would shorten a diagonal's period to lcm(rows, cols), 40
      # instead of 168, and nothing else would notice.
      assert Integer.gcd(@spec_v1.rows, @spec_v1.cols) == 1
    end

    test "the emoji labels are still in their frozen order" do
      card = Card.new()

      assert Enum.map(card.row_labels, & &1.char) == ~w(🐳 🐝 🐙 🦙 🐧 🐷 🐢 🐘)

      assert Enum.map(card.col_labels, & &1.char) ==
               ~w(🍕 🌵 🎸 🔑 🍄 ⚡ 🚀 🍌 🌻 🎩 🌲 🍆 ⌛ 🔥 🍺 🌊 💡 🌈 🎉 ⭐ 🍀)
    end
  end

  describe "special characters" do
    test "reaches every symbol, in every row" do
      # 300 cards, because any one card can miss a given symbol by chance.
      chars =
        1..300
        |> Enum.flat_map(fn _ -> List.flatten(Card.new(symbols: true).grid) end)
        |> MapSet.new()

      assert MapSet.subset?(MapSet.new(symbols()), chars)
      assert MapSet.equal?(chars, MapSet.new(Tuple.to_list(@spec_v1.symbol_alphabet)))
    end

    test "a card generated without them never contains one" do
      chars =
        1..50
        |> Enum.flat_map(fn _ -> List.flatten(Card.new(symbols: false).grid) end)
        |> MapSet.new()

      assert MapSet.disjoint?(chars, MapSet.new(symbols()))
      assert Card.new(symbols: false).symbols == false
      assert Card.new(symbols: true).symbols == true
    end

    test "the choice rides in the id, so a reprint keeps it" do
      card = Card.new(symbols: true)

      assert {:ok, rebuilt} = Card.from_id(card.id)
      assert rebuilt.symbols
      assert rebuilt.grid == card.grid
    end

    test "mistyping the flag is caught like any other typo" do
      seed = :binary.copy(<<19>>, 10)
      symbol_id = Id.encode(Spec.with_symbols(seed, true), 1)
      plain_id = Id.encode(Spec.with_symbols(seed, false), 1)

      # "V1-" occupies 0..2, so the flag is the character at index 3.
      refute String.at(symbol_id, 3) == String.at(plain_id, 3)

      typo =
        symbol_id
        |> String.graphemes()
        |> List.replace_at(3, String.at(plain_id, 3))
        |> Enum.join()

      assert Card.from_id(typo) == {:error, :bad_checksum}
    end

    test "toggling the flag changes the whole grid, not sixteen cells" do
      seed = :binary.copy(<<19>>, 10)

      {:ok, plain} = Card.from_id(Id.encode(Spec.with_symbols(seed, false), 1))
      {:ok, fancy} = Card.from_id(Id.encode(Spec.with_symbols(seed, true), 1))

      assert Enum.all?(0..7, fn row -> Enum.at(plain.grid, row) != Enum.at(fancy.grid, row) end)
    end

    test "the symbol alphabet has no character twice over" do
      alphabet = Tuple.to_list(@spec_v1.symbol_alphabet)

      assert length(alphabet) == 78
      assert length(Enum.uniq(alphabet)) == 78

      assert Enum.take(alphabet, tuple_size(@spec_v1.alphabet)) ==
               Tuple.to_list(@spec_v1.alphabet)
    end

    test "no symbol is one a reader could mistake for another glyph" do
      assert Enum.all?(symbols(), &(String.length(&1) == 1))
      refute Enum.any?(symbols(), &(&1 in ~w(" ' ` | \\ / , . : - _ ~ [ ] { })))
      assert Enum.all?(symbols(), &(&1 =~ ~r/^[[:punct:]]$/))
    end
  end

  describe "emoji labels" do
    test "there is exactly one label per row and per column" do
      card = Card.new()

      assert length(card.row_labels) == @spec_v1.rows
      assert length(card.col_labels) == @spec_v1.cols
    end

    test "no emoji appears on both axes" do
      card = Card.new()
      rows = MapSet.new(card.row_labels, & &1.slug)
      columns = MapSet.new(card.col_labels, & &1.slug)

      assert MapSet.disjoint?(rows, columns)
    end

    test "every label is unique and safely encoded" do
      card = Card.new()
      labels = card.row_labels ++ card.col_labels

      assert length(Enum.uniq_by(labels, & &1.slug)) == length(labels)
      assert length(Enum.uniq_by(labels, & &1.char)) == length(labels)

      for label <- labels do
        # Single codepoint: modifiers and variation selectors break slicing.
        assert String.length(label.char) == 1
        assert [_codepoint] = String.to_charlist(label.char)
        assert label.name =~ ~r/^[a-z ]+$/
        assert label.color =~ ~r/^#[0-9a-f]{6}$/
      end
    end
  end

  describe "row bands" do
    test "every row has its own tint" do
      tints = Enum.map(Card.new().row_labels, & &1.tint)

      assert Enum.all?(tints, &(&1 =~ ~r/^#[0-9a-f]{6}$/))
      assert length(Enum.uniq(tints)) == length(tints)
    end

    test "the tints sit at a similar lightness" do
      lightness = Enum.map(Card.new().row_labels, &luminance(&1.tint))

      assert Enum.max(lightness) - Enum.min(lightness) < 0.06
    end

    test "no two adjacent rows are near-identical bands" do
      Card.new().row_labels
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [above, below] ->
        assert color_distance(above.tint, below.tint) > 15,
               "#{above.name} and #{below.name} bands are too close to tell apart"
      end)
    end

    test "the accent stays saturated enough to read as an edge" do
      for label <- Card.new().row_labels do
        assert luminance(label.color) < luminance(label.tint) - 0.2
      end
    end
  end

  describe "locate/3" do
    test "resolves a cell named by its two emoji" do
      card = Card.new()

      assert Card.locate(card, :whale, :pizza) == {:ok, {0, 0}}
      assert Card.locate(card, :elephant, :clover) == {:ok, {7, 20}}
      assert Card.locate(card, :octopus, :hourglass) == {:ok, {2, 12}}
    end

    test "refuses an emoji used on the wrong axis" do
      card = Card.new()

      assert Card.locate(card, :pizza, :octopus) == :error
      assert Card.locate(card, :octopus, :nonsense) == :error
    end

    test "round-trips into read/5" do
      card = Card.new()
      {:ok, {row, col}} = Card.locate(card, :bee, :rocket)

      assert Card.read(card, row, col, 1) == cell(card, 1, 6)
    end
  end

  describe "character distribution" do
    test "does not favour the characters a naive modulo would" do
      # 256 = 4 * 62 + 8, so a raw `rem/2` would give the first eight characters
      # five slots against the other 54's four.
      alphabet = Tuple.to_list(@spec_v1.alphabet)
      {favoured, rest} = Enum.split(alphabet, 8)

      counts =
        1..300
        |> Enum.flat_map(fn _ -> List.flatten(Card.new().grid) end)
        |> Enum.frequencies()

      mean = fn chars -> Enum.sum(Enum.map(chars, &Map.get(counts, &1, 0))) / length(chars) end
      ratio = mean.(favoured) / mean.(rest)

      assert ratio < 1.10,
             "first 8 characters appear #{Float.round(ratio, 3)}x as often as the rest"

      assert Enum.all?(alphabet, &Map.has_key?(counts, &1))
    end
  end

  describe "read/5" do
    setup do
      {:ok, card} = Card.from_id(Id.encode(:binary.copy(<<7>>, 10), 1))
      %{card: card}
    end

    test "reads left to right from the chosen cell", %{card: card} do
      assert Card.read(card, 0, 0, 8) == "WC4CU9jY"
      assert Card.read(card, 0, 3, 4) == "CU9j"
    end

    test "reads down and diagonally", %{card: card} do
      assert Card.read(card, 0, 0, 4, :down) == column_of(card, 0, 0..3)
      assert Card.read(card, 0, 0, 4, :down_right) == Enum.map_join(0..3, &cell(card, &1, &1))
    end

    test "reads every direction back the way it came", %{card: card} do
      for {forward, backward} <- [
            {:right, :left},
            {:down, :up},
            {:down_right, :up_left},
            {:down_left, :up_right}
          ] do
        [{row, col} | _rest] = trail = Card.trail(card, 3, 9, 6, forward)
        {last_row, last_col} = List.last(trail)

        assert Card.read(card, last_row, last_col, 6, backward) ==
                 card |> Card.read(row, col, 6, forward) |> String.reverse()
      end
    end

    test "continues onto the next row or column instead of running off the edge", %{card: card} do
      last_col = @spec_v1.cols - 1

      assert Card.read(card, 0, last_col - 1, 4) ==
               cell(card, 0, last_col - 1) <>
                 cell(card, 0, last_col) <> cell(card, 1, 0) <> cell(card, 1, 1)

      assert Card.read(card, @spec_v1.rows - 1, 0, 2, :down) ==
               cell(card, @spec_v1.rows - 1, 0) <> cell(card, 0, 1)
    end

    test "tours the whole grid before repeating itself", %{card: card} do
      cells = @spec_v1.rows * @spec_v1.cols

      for direction <- directions() do
        tour = Card.read(card, 0, 0, cells, direction)

        assert String.length(tour) == cells
        assert Card.read(card, 0, 0, cells + 3, direction) == tour <> String.slice(tour, 0, 3)
      end
    end
  end

  describe "trail/5" do
    setup do
      {:ok, card} = Card.from_id(Id.encode(:binary.copy(<<7>>, 10), 1))
      %{card: card}
    end

    test "names the cells the same read returns, in the same order", %{card: card} do
      for direction <- directions(), len <- [1, 8, 12, 20] do
        trail = Card.trail(card, 2, 5, len, direction)

        assert length(trail) == len

        assert Enum.map_join(trail, fn {row, col} -> cell(card, row, col) end) ==
                 Card.read(card, 2, 5, len, direction)
      end
    end

    test "starts where it was asked to", %{card: card} do
      for direction <- directions() do
        assert hd(Card.trail(card, 3, 7, 5, direction)) == {3, 7}
      end
    end

    test "stays on the card however far it runs", %{card: card} do
      cells = @spec_v1.rows * @spec_v1.cols

      for direction <- directions() do
        trail = Card.trail(card, 7, 20, cells + 5, direction)

        assert Enum.all?(trail, fn {row, col} ->
                 row in 0..(@spec_v1.rows - 1) and col in 0..(@spec_v1.cols - 1)
               end)
      end
    end
  end

  defp directions do
    [:right, :left, :down, :up, :down_right, :down_left, :up_right, :up_left]
  end

  # Whatever sits past the plain alphabet.
  defp symbols do
    Enum.drop(Tuple.to_list(@spec_v1.symbol_alphabet), tuple_size(@spec_v1.alphabet))
  end

  defp rgb("#" <> hex), do: for(<<pair::binary-2 <- hex>>, do: String.to_integer(pair, 16))

  defp luminance(hex) do
    [r, g, b] = rgb(hex)
    (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
  end

  defp color_distance(a, b) do
    [ra, ga, ba] = rgb(a)
    [rb, gb, bb] = rgb(b)

    :math.sqrt(:math.pow(ra - rb, 2) + :math.pow(ga - gb, 2) + :math.pow(ba - bb, 2))
  end

  defp cell(card, row, col), do: card.grid |> Enum.at(row) |> Enum.at(col)

  defp column_of(card, col, rows), do: Enum.map_join(rows, &cell(card, &1, col))
end
