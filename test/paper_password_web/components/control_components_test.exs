defmodule PaperPasswordWeb.ControlComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import PaperPasswordWeb.RenderedCard

  alias PaperPassword.Card
  alias PaperPasswordWeb.ControlComponents

  @card_id "V1-000G-40R4-0M30-E209Y"
  @lengths [8, 10, 12, 16, 20]
  @counts [1, 2, 4, 8]
  @formats [print: "Wallet card", phone: "Phone screen"]
  @example_id "V1-ABCD-EFGH-1234-56789"

  setup do
    {:ok, card} = Card.from_id(@card_id)
    %{card: card}
  end

  describe "format_switch/1" do
    test "offers every format it was given" do
      html =
        render_component(&ControlComponents.format_switch/1, format: :print, formats: @formats)

      assert html =~ "Wallet card"
      assert html =~ "Phone screen"
      assert html =~ ~s(id="format-print")
      assert html =~ ~s(id="format-phone")
    end

    test "presses the one that is showing" do
      html =
        render_component(&ControlComponents.format_switch/1, format: :phone, formats: @formats)

      document = Floki.parse_document!(html)

      assert Floki.attribute(document, "#format-phone", "aria-pressed") == ["true"]
      assert Floki.attribute(document, "#format-print", "aria-pressed") == ["false"]
    end
  end

  describe "reader/1" do
    test "shows the password the selected cell gives", %{card: card} do
      html = reader(card, selection: {3, 7}, length: 12, direction: :right)

      assert password(html) == Card.read(card, 3, 7, 12, :right) |> String.graphemes()
    end

    test "names the cell the way a person would say it", %{card: card} do
      html = reader(card, selection: {2, 0})

      assert html =~ "Starting at"
      assert html =~ Enum.at(card.row_labels, 2).name
      assert html =~ Enum.at(card.col_labels, 0).name
    end

    test "re-reads for a different length", %{card: card} do
      short = reader(card, selection: {0, 0}, length: 8)
      long = reader(card, selection: {0, 0}, length: 20)

      assert length(password(short)) == 8
      assert length(password(long)) == 20
      assert Enum.take(password(long), 8) == password(short)
    end

    test "re-reads for a different direction", %{card: card} do
      across = reader(card, selection: {0, 0}, direction: :right)
      down = reader(card, selection: {0, 0}, direction: :down)

      refute password(across) == password(down)
    end

    test "presses the length and direction in use", %{card: card} do
      document = reader(card, length: 16, direction: :up_left) |> Floki.parse_document!()

      pressed = fn selector ->
        document |> Floki.find(selector) |> Floki.attribute("aria-pressed")
      end

      assert pressed.("button[phx-value-length=16]") == ["true"]
      assert pressed.("button[phx-value-length=8]") == ["false"]
      assert pressed.("button[phx-value-direction=up_left]") == ["true"]
      assert pressed.("button[phx-value-direction=right]") == ["false"]
    end

    test "offers every length it was given, and no others", %{card: card} do
      offered =
        reader(card)
        |> Floki.parse_document!()
        |> Floki.find("button[phx-value-length]")
        |> Floki.attribute("phx-value-length")

      assert offered == Enum.map(@lengths, &to_string/1)
    end

    test "turns the compass with the card", %{card: card} do
      wallet = reader(card, format: :print)

      assert compass_key(wallet, :right) == "right"
      assert compass_key(wallet, :up) == "up"

      phone = reader(card, format: :phone)

      assert compass_key(phone, :right) == "down"
      assert compass_key(phone, :down) == "right"
      assert compass_key(phone, :up) == "left"
      assert compass_key(phone, :up_left) == "up and left"
      assert compass_key(phone, :down_right) == "down and right"
    end

    test "keeps a word on every arrow for a screen reader", %{card: card} do
      labels =
        reader(card)
        |> Floki.parse_document!()
        |> Floki.find("button[phx-value-direction]")
        |> Floki.attribute("aria-label")

      assert length(labels) == 8
      assert "up and left" in labels
      refute Enum.any?(labels, &(&1 == ""))
    end
  end

  describe "controls/1" do
    test "offers the counts and the monochrome toggle only for the wallet card" do
      html = controls(format: :print)

      assert html =~ "phx-click=\"set_count\""
      assert html =~ "mono-toggle"
      assert html =~ "print-card"
    end

    test "offers saving an image only for the phone card" do
      html = controls(format: :phone)

      assert html =~ "save-image"
      refute html =~ "phx-click=\"set_count\""
      refute html =~ "mono-toggle"
      refute html =~ "print-card"
    end

    test "says what saving an image to a phone actually costs" do
      assert controls(format: :phone) =~ "never"
      assert controls(format: :phone) =~ "syncs"
      refute controls(format: :print) =~ "syncs"
    end

    test "counts the cards in the button copy" do
      assert button_text(controls(count: 1), "#print-card") == "Print"
      assert button_text(controls(count: 4), "#print-card") == "Print 4 cards"
      assert button_text(controls(count: 1), "button[phx-click=new_card]") == "New card"
      assert button_text(controls(count: 4), "button[phx-click=new_card]") == "New cards"
    end

    test "a phone always says New card, however many the wallet view held" do
      html = controls(count: 4, format: :phone)

      assert button_text(html, "button[phx-click=new_card]") == "New card"
    end

    test "offers every count it was given" do
      offered =
        controls()
        |> Floki.parse_document!()
        |> Floki.find("button[phx-value-count]")
        |> Floki.attribute("phx-value-count")

      assert offered == Enum.map(@counts, &to_string/1)
    end

    test "presses the count in use" do
      document = controls(count: 4) |> Floki.parse_document!()

      assert Floki.attribute(document, "button[phx-value-count=4]", "aria-pressed") == ["true"]
      assert Floki.attribute(document, "button[phx-value-count=1]", "aria-pressed") == ["false"]
    end

    test "calls the PIN row a column on the phone card" do
      assert controls(format: :print) =~ "A row for PINs"
      refute controls(format: :print) =~ "A column for PINs"

      assert controls(format: :phone) =~ "A column for PINs"
      refute controls(format: :phone) =~ "A row for PINs"
    end

    test "reflects each toggle's state" do
      on = controls(symbols: true, pin_row: true, mono: true)

      assert toggled_on?(on, "#symbols-toggle")
      assert toggled_on?(on, "#pin-row-toggle")
      assert toggled_on?(on, "#mono-toggle")

      off = controls()

      refute toggled_on?(off, "#symbols-toggle")
      refute toggled_on?(off, "#pin-row-toggle")
      refute toggled_on?(off, "#mono-toggle")
    end

    test "each toggle is a switch with a label a screen reader can find" do
      document = controls() |> Floki.parse_document!()

      for id <- ~w(symbols-toggle pin-row-toggle mono-toggle) do
        assert Floki.attribute(document, "##{id}", "role") == ["switch"]
        assert Floki.attribute(document, "##{id}", "aria-labelledby") == ["#{id}-label"]
        assert Floki.find(document, "##{id}-label") != []
      end
    end

    test "shows the specimen as a placeholder rather than a value" do
      document = controls() |> Floki.parse_document!()

      assert Floki.attribute(document, "#card-id", "placeholder") == [@example_id]
      assert Floki.attribute(document, "#card-id", "value") == []
    end

    test "shows a load error when there is one" do
      refute controls() =~ "text-red-600"
      assert controls(load_error: "That doesn't look right") =~ "That doesn&#39;t look right"
    end
  end

  describe "how_it_works/1" do
    test "tells the wallet reader to print and the phone reader to save" do
      print = render_component(&ControlComponents.how_it_works/1, format: :print)
      phone = render_component(&ControlComponents.how_it_works/1, format: :phone)

      assert print =~ "Print the card"
      refute print =~ "Save the image"

      assert phone =~ "Save the image"
      refute phone =~ "Print the card"
    end

    test "explains that a run is different cards rather than copies" do
      print = render_component(&ControlComponents.how_it_works/1, format: :print)

      assert print =~ "not copies"
      assert print =~ "every card has its own ID"
    end

    test "warns that losing the id loses the passwords, in both formats" do
      for format <- [:print, :phone] do
        html = render_component(&ControlComponents.how_it_works/1, format: format)

        # Literal template copy: the apostrophe is not escaped here.
        assert html =~ "keep track of the card's ID"
      end
    end
  end

  defp button_text(html, selector) do
    html |> Floki.parse_document!() |> Floki.find(selector) |> Floki.text() |> String.trim()
  end

  defp reader(card, opts \\ []) do
    render_component(
      &ControlComponents.reader/1,
      Keyword.merge(
        [
          card: card,
          selection: {0, 0},
          length: 12,
          direction: :right,
          format: :print,
          lengths: @lengths
        ],
        opts
      )
    )
  end

  defp controls(opts \\ []) do
    render_component(
      &ControlComponents.controls/1,
      Keyword.merge(
        [
          load_error: nil,
          example_id: @example_id,
          symbols: false,
          pin_row: false,
          mono: false,
          count: 1,
          format: :print,
          counts: @counts
        ],
        opts
      )
    )
  end
end
