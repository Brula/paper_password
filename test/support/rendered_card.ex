defmodule PaperPasswordWeb.RenderedCard do
  @moduledoc """
  Reads a card back out of the HTML that drew it.

  Shared by the component tests and the LiveView test. These are extractors,
  not assertions: each one answers "what does the markup actually say" so a
  test can compare it against what the card was built from. Anything that
  encodes an *expectation* belongs in the test, not here.
  """

  @doc "Every card on the page, as a grid of characters, in document order."
  def grids(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find(".card")
    |> Enum.map(fn card ->
      card
      |> Floki.find("tbody tr")
      |> Enum.map(fn row ->
        row |> Floki.find("td") |> Enum.map(&String.trim(Floki.text(&1)))
      end)
    end)
  end

  @doc "The first card on the page, as a grid of characters."
  def grid(html), do: html |> grids() |> List.first()

  @doc """
  The portrait card, read back into the card's own orientation.

  So it can be compared cell for cell with what the printable one renders:
  transposing the view must not transpose the coordinates.
  """
  def phone_grid(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#phone-card tbody tr")
    |> Enum.map(fn row ->
      row |> Floki.find("td") |> Enum.map(&String.trim(Floki.text(&1)))
    end)
    |> Enum.zip_with(& &1)
  end

  @doc """
  The printed id of every card on the page.

  Off the id line rather than the whole page, so the specimen in the load
  field's placeholder doesn't count as a card.
  """
  def ids(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find(".card-id-line")
    |> Enum.map(&String.trim(Floki.text(&1)))
  end

  @doc "The printed id of the first card on the page."
  def id(html), do: html |> ids() |> List.first()

  @doc "How many cards are peeking out from under the one on top."
  def peeking(html) do
    html |> Floki.parse_document!() |> Floki.find(".stack-slot--peek") |> length()
  end

  @doc "The id of the card currently on top of the stack."
  def on_top(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find(".stack-slot:not(.stack-slot--peek) .card-id-line")
    |> Floki.text()
    |> String.trim()
  end

  @doc """
  The cells carrying `class`, as `{row, col}`, in the order they appear.

  Scoped to cells that answer to a click, which is the card on top and no
  other. A clipped card in the stack carries no handler.
  """
  def marked(html, class) do
    html
    |> Floki.parse_document!()
    |> Floki.find("td[phx-click]")
    |> Enum.filter(&(&1 |> Floki.attribute("class") |> hd() |> String.contains?(class)))
    |> Enum.map(fn cell ->
      [row] = Floki.attribute(cell, "phx-value-row")
      [col] = Floki.attribute(cell, "phx-value-col")
      {String.to_integer(row), String.to_integer(col)}
    end)
  end

  @doc "The password the reader is showing, as its characters."
  def password(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("section.print\\:hidden p.font-mono")
    |> Floki.text()
    |> String.trim()
    |> String.graphemes()
  end

  @doc """
  What the compass key for `direction` is called.

  The name belongs to the key's position on screen, so it moves when the card
  is transposed.
  """
  def compass_key(html, direction) do
    html
    |> Floki.parse_document!()
    |> Floki.attribute("button[phx-value-direction=#{direction}]", "aria-label")
    |> hd()
  end

  @doc "Whether the toggle at `selector` is switched on."
  def toggled_on?(html, selector) do
    html
    |> Floki.parse_document!()
    |> Floki.attribute(selector, "aria-checked") == ["true"]
  end

  @doc "The `--row-tint` of every row band, top row first."
  def row_tints(html), do: row_property(html, "--row-tint")

  @doc "The `--row-accent` of every row band, top row first."
  def row_accents(html), do: row_property(html, "--row-accent")

  # Reads exactly what the CSS is handed.
  defp row_property(html, property) do
    html
    |> Floki.parse_document!()
    |> Floki.find(".card tbody tr.row-band")
    |> Enum.map(fn row ->
      [style] = Floki.attribute(row, "style")
      [_whole, value] = Regex.run(~r/#{property}:\s*([^;]+)/, style)
      String.trim(value)
    end)
  end

  @doc "Whether `char` is drawn from the punctuation the symbols toggle adds."
  def symbol?(char), do: char =~ ~r/^[^0-9a-zA-Z]$/

  @doc "The rows of `grid` that hold nothing but digits."
  def digit_rows(grid) do
    Enum.filter(grid, fn row -> Enum.all?(row, &(&1 =~ ~r/^[0-9]$/)) end)
  end
end
