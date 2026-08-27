defmodule PaperPasswordWeb.HomeLiveTest do
  @moduledoc """
  The page as a machine: what each event does to the run on screen.

  What the markup *looks like* is tested in isolation next door, in
  `PaperPasswordWeb.CardComponentsTest` and
  `PaperPasswordWeb.ControlComponentsTest`. What is here is the wiring: that
  an event reaches the right assign, that the assign reaches the right
  component, and that a value arriving over the socket is checked before it
  reaches either.
  """
  use PaperPasswordWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PaperPasswordWeb.RenderedCard

  alias PaperPassword.Card

  # The static render: a different code path from `live/2`.
  test "serves a card on a plain GET", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert html_response(conn, 200) =~ "Your passwords, on"
  end

  test "renders a card on the homepage", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")

    assert html =~ "Your passwords, on"
    assert html =~ "🐙"
    assert html =~ "🍕"
    assert html =~ ~r/V1-[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{5}/
  end

  test "generates a different card on demand", %{conn: conn} do
    {:ok, live, html} = live(conn, ~p"/")
    before = id(html)

    after_click = live |> element("button", "New card") |> render_click()

    refute id(after_click) == before
  end

  describe "reprinting by id" do
    test "reprints an existing card from its id", %{conn: conn} do
      card = Card.new()
      {:ok, live, _html} = live(conn, ~p"/")

      html = live |> form("form", %{"card_id" => card.id}) |> render_submit()

      assert html =~ card.id
      assert grid(html) == card.grid
    end

    test "reprints from an id retyped without its hyphens", %{conn: conn} do
      card = Card.new()
      {:ok, live, _html} = live(conn, ~p"/")

      squashed = String.replace(card.id, "-", "")
      html = live |> form("form", %{"card_id" => squashed}) |> render_submit()

      assert grid(html) == card.grid
      assert html =~ card.id
    end

    test "explains a mistyped id instead of showing the wrong card", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      html = live |> form("form", %{"card_id" => "V1-AAAA-AAAA-AAAA-AAAAA"}) |> render_submit()

      assert html =~ "Check for a mistyped character"
    end

    test "says the placeholder specimen is only an example", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      html = live |> form("form", %{"card_id" => "V1-ABCD-EFGH-1234-56789"}) |> render_submit()

      assert html =~ "just the example"
      refute html =~ "Check for a mistyped character"
    end

    test "recognises the example however it was typed", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      html = live |> form("form", %{"card_id" => " v1 abcd efgh 1234 56789 "}) |> render_submit()

      assert html =~ "just the example"
    end

    test "says so when nothing was filled in", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      html = live |> form("form", %{"card_id" => "   "}) |> render_submit()

      assert html =~ "Nothing filled in"
    end

    test "rejects an id that isn't one at all", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      html = live |> form("form", %{"card_id" => "hello"}) |> render_submit()

      assert html =~ "isn&#39;t a card ID"
    end
  end

  describe "special characters toggle" do
    test "deals a new card with symbols in it", %{conn: conn} do
      {:ok, live, html} = live(conn, ~p"/")
      refute Enum.any?(List.flatten(grid(html)), &symbol?/1)

      html = live |> element("#symbols-toggle") |> render_click()

      assert Enum.any?(List.flatten(grid(html)), &symbol?/1)
      assert toggled_on?(html, "#symbols-toggle")
    end

    test "toggling back off returns to an alphanumeric card", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      live |> element("#symbols-toggle") |> render_click()
      html = live |> element("#symbols-toggle") |> render_click()

      refute Enum.any?(List.flatten(grid(html)), &symbol?/1)
      refute toggled_on?(html, "#symbols-toggle")
    end

    test "keeps dealing symbol cards while it is on", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")
      live |> element("#symbols-toggle") |> render_click()

      html = live |> element("button", "New card") |> render_click()

      assert Enum.any?(List.flatten(grid(html)), &symbol?/1)
    end

    test "follows the card loaded by id rather than the other way round", %{conn: conn} do
      card = Card.new(symbols: true)
      {:ok, live, _html} = live(conn, ~p"/")

      html = live |> form("form", %{"card_id" => card.id}) |> render_submit()

      assert grid(html) == card.grid
      assert toggled_on?(html, "#symbols-toggle")
    end
  end

  describe "PIN row toggle" do
    test "deals a new card with one digits-only row", %{conn: conn} do
      {:ok, live, html} = live(conn, ~p"/")
      assert digit_rows(grid(html)) == []

      html = live |> element("#pin-row-toggle") |> render_click()

      assert length(digit_rows(grid(html))) == 1
      assert toggled_on?(html, "#pin-row-toggle")
    end

    test "toggling back off returns to a card without one", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      live |> element("#pin-row-toggle") |> render_click()
      html = live |> element("#pin-row-toggle") |> render_click()

      assert digit_rows(grid(html)) == []
      refute toggled_on?(html, "#pin-row-toggle")
    end

    test "combines with the symbols toggle", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      live |> element("#symbols-toggle") |> render_click()
      html = live |> element("#pin-row-toggle") |> render_click()

      grid = grid(html)

      assert length(digit_rows(grid)) == 1
      assert Enum.any?(List.flatten(grid), &symbol?/1)
      assert toggled_on?(html, "#symbols-toggle")
      assert toggled_on?(html, "#pin-row-toggle")
    end

    test "follows the card loaded by id rather than the other way round", %{conn: conn} do
      card = Card.new(pin_row: true)
      {:ok, live, _html} = live(conn, ~p"/")

      html = live |> form("form", %{"card_id" => card.id}) |> render_submit()

      assert grid(html) == card.grid
      assert toggled_on?(html, "#pin-row-toggle")
    end
  end

  describe "monochrome toggle" do
    test "repaints the run instead of redealing it", %{conn: conn} do
      {:ok, live, html} = live(conn, ~p"/")
      before_id = id(html)
      before_grid = grid(html)

      html = live |> element("#mono-toggle") |> render_click()

      assert id(html) == before_id
      assert grid(html) == before_grid
      assert toggled_on?(html, "#mono-toggle")
    end

    test "reaches the card on screen", %{conn: conn} do
      {:ok, live, html} = live(conn, ~p"/")
      assert "#dceafa" in row_tints(html)

      html = live |> element("#mono-toggle") |> render_click()

      assert Enum.uniq(row_accents(html)) == ["#000000"]
    end

    test "toggling back off restores the palette", %{conn: conn} do
      {:ok, live, html} = live(conn, ~p"/")
      before = row_tints(html)

      live |> element("#mono-toggle") |> render_click()
      html = live |> element("#mono-toggle") |> render_click()

      assert row_tints(html) == before
      refute toggled_on?(html, "#mono-toggle")
    end

    test "survives a redeal from the other toggles", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")
      live |> element("#mono-toggle") |> render_click()

      html = live |> element("#symbols-toggle") |> render_click()

      assert Enum.uniq(row_accents(html)) == ["#000000"]
      assert toggled_on?(html, "#mono-toggle")
    end
  end

  describe "a run of several cards" do
    test "deals as many cards as asked for", %{conn: conn} do
      {:ok, live, html} = live(conn, ~p"/")
      assert length(ids(html)) == 1

      html = live |> element("button[phx-value-count=4]") |> render_click()

      assert length(ids(html)) == 4
    end

    test "the cards in a run are different from one another", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      html = live |> element("button[phx-value-count=8]") |> render_click()

      assert length(Enum.uniq(ids(html))) == 8
      assert length(Enum.uniq(grids(html))) == 8
    end

    test "growing a run keeps the cards already dealt", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      two = live |> element("button[phx-value-count=2]") |> render_click() |> ids()
      four = live |> element("button[phx-value-count=4]") |> render_click() |> ids()

      assert Enum.take(four, 2) == two
    end

    test "shrinking a run drops the tail rather than redealing", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      four = live |> element("button[phx-value-count=4]") |> render_click() |> ids()
      two = live |> element("button[phx-value-count=2]") |> render_click() |> ids()

      assert two == Enum.take(four, 2)
    end

    test "stacks the whole run, so it can be counted by looking", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      html = live |> element("button[phx-value-count=4]") |> render_click()

      assert length(ids(html)) == 4
      assert peeking(html) == 3
    end

    test "is not a stack when the run is one card", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/")

      assert peeking(html) == 0
      refute html =~ "stack-cover"
    end

    test "New card redeals the whole run at the current count", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")
      before = live |> element("button[phx-value-count=4]") |> render_click() |> ids()

      after_click = live |> element("button", "New cards") |> render_click() |> ids()

      assert length(after_click) == 4
      assert MapSet.disjoint?(MapSet.new(before), MapSet.new(after_click))
    end

    test "the toggles redeal every card in the run", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")
      live |> element("button[phx-value-count=4]") |> render_click()

      html = live |> element("#symbols-toggle") |> render_click()

      assert length(ids(html)) == 4
      assert Enum.all?(grids(html), &Enum.any?(List.flatten(&1), fn c -> symbol?(c) end))
    end

    test "loading an id reprints that card alone", %{conn: conn} do
      card = Card.new()
      {:ok, live, _html} = live(conn, ~p"/")
      live |> element("button[phx-value-count=8]") |> render_click()

      html = live |> form("form", %{"card_id" => card.id}) |> render_submit()

      assert ids(html) == [card.id]
    end

    test "flips to any card in the run, not just the next one", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")
      ids = live |> element("button[phx-value-count=4]") |> render_click() |> ids()

      assert on_top(render(live)) == Enum.at(ids, 3)

      html = live |> element("button[phx-value-index=0]") |> render_click()
      assert on_top(html) == Enum.at(ids, 0)
      assert peeking(html) == 3

      html = live |> element("button[phx-value-index=1]") |> render_click()
      assert on_top(html) == Enum.at(ids, 1)
      assert peeking(html) == 3
    end

    test "only the card on top is clickable", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")
      live |> element("button[phx-value-count=4]") |> render_click()

      html = live |> element("button[phx-value-index=1]") |> render_click()
      document = Floki.parse_document!(html)

      assert document |> Floki.find(".stack-slot--peek td[phx-click]") == []
      assert document |> Floki.find(".stack-slot:not(.stack-slot--peek) td[phx-click]") != []
    end

    test "reads the card on top of the deck", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")
      live |> element("button[phx-value-count=4]") |> render_click()
      live |> element("td[phx-value-row=0][phx-value-col=0]") |> render_click()

      first = password(render(live))
      second = live |> element("button[phx-value-index=1]") |> render_click() |> password()

      refute second == first
      assert second == render(live) |> grids() |> Enum.at(1) |> hd() |> Enum.take(12)
    end

    test "a shrinking run brings the stack back onto it", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")
      live |> element("button[phx-value-count=8]") |> render_click()
      live |> element("button[phx-value-index=0]") |> render_click()

      html = live |> element("button[phx-value-count=2]") |> render_click()

      assert peeking(html) == 1
      assert on_top(html) == html |> ids() |> Enum.at(1)
    end

    test "still prints the whole run, however far it was flipped", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")
      live |> element("button[phx-value-count=4]") |> render_click()

      html = live |> element("button[phx-value-index=2]") |> render_click()

      assert length(ids(html)) == 4
      assert html |> Floki.parse_document!() |> Floki.find(".card-slot") |> length() == 4
      assert peeking(html) == 3
    end

    test "ignores an index that isn't a card in the run", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")
      ids = live |> element("button[phx-value-count=4]") |> render_click() |> ids()

      for claim <- ["4", "-1", "99999", "nonsense"] do
        html = render_click(live, "show_card", %{"index" => claim})
        assert on_top(html) == Enum.at(ids, 3)
      end
    end

    test "ignores a count it never offered", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      html = render_click(live, "set_count", %{"count" => "100000"})

      assert length(ids(html)) == 1
    end
  end

  describe "the phone format" do
    test "shows the same card, switching never redeals", %{conn: conn} do
      {:ok, live, html} = live(conn, ~p"/")
      before = id(html)
      before_grid = grid(html)

      phone = live |> element("#format-phone") |> render_click()
      assert id(phone) == before
      assert phone_grid(phone) == before_grid

      back = live |> element("#format-print") |> render_click()
      assert id(back) == before
      assert grid(back) == before_grid
    end

    test "shows one card and never a stack", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")
      live |> element("button[phx-value-count=4]") |> render_click()

      html = live |> element("#format-phone") |> render_click()
      document = Floki.parse_document!(html)

      assert document |> Floki.find(".phone-card") |> length() == 1
      assert document |> Floki.find(".stack-cover") == []
      assert document |> Floki.attribute("[id^=phone-card]", "id") == ["phone-card"]
    end

    test "leaves the printable sheet off the page", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      html = live |> element("#format-phone") |> render_click()

      assert html |> Floki.parse_document!() |> Floki.find(".card") == []
      assert html =~ "Save image"
      refute html =~ "phx-click=\"set_count\""
    end

    test "reads a password from a cell chosen on the portrait card", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")
      live |> element("#format-phone") |> render_click()

      html = live |> element("#phone-card td[phx-value-row=0][phx-value-col=0]") |> render_click()

      assert html =~ "octopus"
      assert html =~ "pizza"
      assert html =~ phone_grid(html) |> hd() |> Enum.take(12) |> Enum.join()
    end

    test "is never where the page starts", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/")

      assert html |> Floki.parse_document!() |> Floki.find(".card") != []
      refute html =~ "phone-card"
    end

    test "ignores a format it never offered", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      html = render_click(live, "set_format", %{"format" => "billboard"})

      assert html |> Floki.parse_document!() |> Floki.find(".card") != []
    end
  end

  describe "reading a password" do
    test "shows the password for the selected cell", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      html = live |> element("td[phx-value-row=0][phx-value-col=0]") |> render_click()

      assert html =~ "Starting at"
      assert html =~ "octopus"
      assert html =~ "pizza"
    end

    test "hides the reader until a cell is chosen", %{conn: conn} do
      {:ok, live, html} = live(conn, ~p"/")
      refute html =~ "Starting at"

      live |> element("td[phx-value-row=1][phx-value-col=1]") |> render_click()
      assert render(live) =~ "Starting at"

      assert live |> element("button", "Clear") |> render_click() =~ "How it works"
      refute render(live) =~ "Starting at"
    end

    test "re-reads when the length and direction change", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")
      live |> element("td[phx-value-row=0][phx-value-col=0]") |> render_click()

      twenty = live |> element("button[phx-value-length=20]") |> render_click()
      eight = live |> element("button[phx-value-length=8]") |> render_click()

      refute twenty == eight

      down = live |> element("button[phx-value-direction=down]") |> render_click()
      refute down == eight
    end

    test "dims the cells the password runs through", %{conn: conn} do
      {:ok, live, html} = live(conn, ~p"/")
      assert marked(html, "bg-brand/20") == []

      html = live |> element("td[phx-value-row=0][phx-value-col=0]") |> render_click()

      # The start is in its own trail, so it must not be marked as both.
      assert marked(html, "bg-brand ") == [{0, 0}]
      assert marked(html, "bg-brand/20") == Enum.map(1..11, &{0, &1})
    end

    test "the dimmed run follows the length and direction", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")
      live |> element("td[phx-value-row=0][phx-value-col=0]") |> render_click()

      html = live |> element("button[phx-value-length=8]") |> render_click()
      assert marked(html, "bg-brand/20") == Enum.map(1..7, &{0, &1})

      html = live |> element("button[phx-value-direction=down]") |> render_click()
      assert marked(html, "bg-brand/20") == Enum.map(1..7, &{&1, 0})
    end

    test "wraps onto the card rather than off it", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      live |> element("td[phx-value-row=7][phx-value-col=19]") |> render_click()
      html = live |> element("button[phx-value-length=8]") |> render_click()

      # Marked cells come back in grid order, so the wrapped head reads first.
      assert marked(html, "bg-brand/20") == Enum.map(0..5, &{0, &1}) ++ [{7, 20}]
    end

    test "reads every direction the compass offers", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")
      live |> element("td[phx-value-row=4][phx-value-col=10]") |> render_click()

      trails =
        for direction <- ~w(right left down up down_right down_left up_right up_left) do
          html = live |> element("button[phx-value-direction=#{direction}]") |> render_click()
          trail = marked(html, "bg-brand/20")

          # The start is drawn in full, so 11 of the 12 are dimmed.
          assert length(trail) == 11
          assert length(Enum.uniq(trail)) == 11
          refute {4, 10} in trail

          trail
        end

      assert length(Enum.uniq(trails)) == 8
    end

    test "clearing the selection clears the run with it", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")
      live |> element("td[phx-value-row=0][phx-value-col=0]") |> render_click()

      html = live |> element("button", "Clear") |> render_click()

      assert marked(html, "bg-brand/20") == []
    end

    test "ignores a direction it never offered", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")
      live |> element("td[phx-value-row=0][phx-value-col=0]") |> render_click()

      html = render_click(live, "set_direction", %{"direction" => "erlang"})

      assert marked(html, "bg-brand/20") == Enum.map(1..11, &{0, &1})
    end

    test "ignores a length it never offered", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")
      live |> element("td[phx-value-row=0][phx-value-col=0]") |> render_click()

      html = render_click(live, "set_length", %{"length" => "100000"})

      assert length(password(html)) == 12
    end

    test "ignores a cell that isn't on the card", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/")

      for {row, col} <- [{8, 0}, {0, 21}, {-1, 0}, {"x", "y"}] do
        html = render_click(live, "select_cell", %{"row" => row, "col" => col})
        refute html =~ "Starting at"
      end
    end
  end
end
