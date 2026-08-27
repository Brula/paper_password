defmodule PaperPasswordWeb.CardComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import PaperPasswordWeb.RenderedCard

  alias PaperPassword.Card
  alias PaperPasswordWeb.CardComponents

  # A known grid, so an assertion can name a cell. Must not change.
  @card_id "V1-000G-40R4-0M30-E209Y"

  setup do
    {:ok, card} = Card.from_id(@card_id)
    %{card: card}
  end

  describe "card_table/1" do
    test "draws every cell of the grid", %{card: card} do
      html = wallet(card)

      assert grid(html) == card.grid
    end

    test "labels the rows with animals and the columns with objects", %{card: card} do
      html = wallet(card)
      document = Floki.parse_document!(html)

      rows = document |> Floki.find("tbody th[scope=row] span") |> Floki.attribute("aria-label")
      cols = document |> Floki.find("thead th[scope=col] span") |> Floki.attribute("aria-label")

      assert rows == Enum.map(card.row_labels, & &1.name)
      assert cols == Enum.map(card.col_labels, & &1.name)
    end

    test "prints the id, which is the only thing that reprints the card", %{card: card} do
      assert id(wallet(card)) == card.id
    end

    test "names the card in a caption for a screen reader", %{card: card} do
      html = wallet(card)

      assert html =~ "Password card #{card.id}"
      assert html =~ "Rows are labelled with animals"
    end

    test "declares a column for the labels and one per object", %{card: card} do
      cols = wallet(card) |> Floki.parse_document!() |> Floki.find("colgroup col")

      assert length(cols) == 1 + length(card.col_labels)
      assert Floki.attribute(hd(cols), "class") == ["label-column"]
    end

    test "carries both palette values on every row band", %{card: card} do
      html = wallet(card)

      assert row_tints(html) == Enum.map(card.row_labels, & &1.tint)
      assert row_accents(html) == Enum.map(card.row_labels, & &1.color)
    end

    test "monochrome alternates one grey and blacks the stripe", %{card: card} do
      html = wallet(card, mono: true)

      assert Enum.uniq(row_tints(html)) == ["#ffffff", "#d4d4d4"]
      assert Enum.uniq(row_accents(html)) == ["#000000"]
      assert html =~ "card--mono"
    end

    test "monochrome repaints without touching a single character", %{card: card} do
      assert grid(wallet(card, mono: true)) == grid(wallet(card))
    end

    test "an interactive card answers to a click on any cell", %{card: card} do
      cells = wallet(card) |> Floki.parse_document!() |> Floki.find("td[phx-click]")

      assert length(cells) == card.spec.rows * card.spec.cols
    end

    test "a card that is not interactive carries no handler at all", %{card: card} do
      document = wallet(card, interactive: false) |> Floki.parse_document!()

      assert Floki.find(document, "td[phx-click]") == []
      assert Floki.find(document, "td[phx-value-row]") == []
    end

    test "marks the selected cell and dims the trail behind it", %{card: card} do
      trail = MapSet.new([{2, 3}, {2, 4}, {2, 5}])
      html = wallet(card, selection: {2, 3}, trail: trail)

      # The start is in its own trail, so it must come back marked once.
      assert marked(html, "bg-brand ") == [{2, 3}]
      assert marked(html, "bg-brand/20") == [{2, 4}, {2, 5}]
    end

    test "marks nothing when no cell is selected", %{card: card} do
      html = wallet(card)

      assert marked(html, "bg-brand ") == []
      assert marked(html, "bg-brand/20") == []
    end

    test "a non-interactive card is never highlighted", %{card: card} do
      html = wallet(card, interactive: false, selection: {0, 0}, trail: MapSet.new([{0, 1}]))

      assert marked(html, "bg-brand") == []
    end

    test "gives each card in a run its own element ids", %{card: card} do
      assert wallet(card, index: 0) =~ ~s(id="card-0")
      assert wallet(card, index: 3) =~ ~s(id="card-3")
      assert wallet(card, index: 3) =~ ~s(id="card-3-id")
    end
  end

  describe "phone_card/1" do
    test "shows the same grid transposed", %{card: card} do
      assert phone_grid(phone(card)) == card.grid
    end

    test "addresses a cell by the card's coordinates, not the view's", %{card: card} do
      cell =
        phone(card)
        |> Floki.parse_document!()
        |> Floki.find("td[phx-value-row=0][phx-value-col=5]")

      assert Floki.text(cell) |> String.trim() == card.grid |> hd() |> Enum.at(5)
    end

    test "puts the animals across the top and the objects down the side", %{card: card} do
      document = phone(card) |> Floki.parse_document!()

      across = document |> Floki.find("thead th[scope=col] span") |> Floki.attribute("aria-label")
      down = document |> Floki.find("tbody th[scope=row] span") |> Floki.attribute("aria-label")

      assert across == Enum.map(card.row_labels, & &1.name)
      assert down == Enum.map(card.col_labels, & &1.name)
    end

    test "moves the bands onto the columns, where the reading now runs", %{card: card} do
      bands = phone(card) |> Floki.parse_document!() |> Floki.find("colgroup col.col-band")

      assert length(bands) == length(card.row_labels)

      styles = Floki.attribute(bands, "style")
      assert Enum.all?(Enum.zip(styles, card.row_labels), fn {s, l} -> s =~ l.tint end)
    end

    test "carries what the saved image needs to draw itself", %{card: card} do
      document = phone(card) |> Floki.parse_document!()

      assert Floki.attribute(document, "#phone-card", "data-card-id") == [card.id]

      heads = Floki.find(document, "thead th[data-animal]")
      assert Floki.attribute(heads, "data-tint") == Enum.map(card.row_labels, & &1.tint)
      assert Floki.attribute(heads, "data-accent") == Enum.map(card.row_labels, & &1.color)
    end

    test "highlights the same coordinates the wallet card would", %{card: card} do
      trail = MapSet.new([{1, 2}, {1, 3}])
      html = phone(card, selection: {1, 2}, trail: trail)

      assert marked(html, "bg-brand ") == [{1, 2}]
      assert marked(html, "bg-brand/20") == [{1, 3}]
    end
  end

  describe "stack_cover/1" do
    test "says which card it brings up, and how many there are" do
      html = render_component(&CardComponents.stack_cover/1, index: 2, count: 8)

      assert html =~ ~s(aria-label="Show card 3 of 8")
      assert html =~ ~s(phx-value-index="2")
      assert html =~ ~s(phx-click="show_card")
    end

    test "is a button, so a keyboard can reach the card underneath" do
      html = render_component(&CardComponents.stack_cover/1, index: 0, count: 2)

      assert html =~ ~s(type="button")
      assert html =~ "focus:ring"
    end
  end

  defp wallet(card, opts \\ []) do
    render_component(
      &CardComponents.card_table/1,
      Keyword.merge(
        [
          card: card,
          index: 0,
          interactive: true,
          selection: nil,
          trail: MapSet.new(),
          mono: false
        ],
        opts
      )
    )
  end

  defp phone(card, opts \\ []) do
    render_component(
      &CardComponents.phone_card/1,
      Keyword.merge(
        [card: card, interactive: true, selection: nil, trail: MapSet.new()],
        opts
      )
    )
  end
end
