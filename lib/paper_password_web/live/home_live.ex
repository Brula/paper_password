defmodule PaperPasswordWeb.HomeLive do
  @moduledoc """
  A run of password cards. The whole application.

  State and events only; `CardComponents` and `ControlComponents` render. Every
  value off the socket is checked against what the UI offers before it reaches
  anything else. See ARCHITECTURE.md.
  """
  use PaperPasswordWeb, :live_view

  import PaperPasswordWeb.CardComponents
  import PaperPasswordWeb.ControlComponents

  alias PaperPassword.Card
  alias PaperPassword.Run
  alias PaperPasswordWeb.Compass
  alias PaperPasswordWeb.Stack

  @lengths [8, 10, 12, 16, 20]

  @formats [print: "Wallet card", phone: "Phone screen"]

  # A cap as much as a menu: the count arrives over the socket. Eight fills a
  # sheet; see `assets/css/print.css`.
  @counts [1, 2, 4, 8]

  # Well-formed but fails its check symbol, so submitting it would otherwise be
  # reported as a typo. `load/1` catches it by name instead.
  @example_id "V1-ABCD-EFGH-1234-56789"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       cards: [Card.new()],
       count: 1,
       current: 0,
       format: :print,
       selection: nil,
       length: 12,
       direction: :right,
       load_error: nil,
       symbols: false,
       pin_row: false,
       mono: false
     )}
  end

  @impl true
  def handle_event("new_card", _params, socket) do
    {:noreply, deal(socket, socket.assigns.symbols, socket.assigns.pin_row)}
  end

  def handle_event("toggle_symbols", _params, socket) do
    {:noreply, deal(socket, not socket.assigns.symbols, socket.assigns.pin_row)}
  end

  def handle_event("toggle_pin_row", _params, socket) do
    {:noreply, deal(socket, socket.assigns.symbols, not socket.assigns.pin_row)}
  end

  # Repaints rather than redeals: a palette does not change what is in a cell.
  def handle_event("toggle_mono", _params, socket) do
    {:noreply, assign(socket, mono: not socket.assigns.mono)}
  end

  # The selection deliberately survives the flip.
  def handle_event("show_card", %{"index" => index}, socket) do
    case index(index, length(socket.assigns.cards)) do
      {:ok, index} -> {:noreply, assign(socket, current: index)}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("set_format", %{"format" => format}, socket) do
    case Enum.find(@formats, fn {value, _label} -> Atom.to_string(value) == format end) do
      {format, _label} -> {:noreply, assign(socket, format: format)}
      nil -> {:noreply, socket}
    end
  end

  def handle_event("set_count", %{"count" => count}, socket) do
    case Integer.parse(to_string(count)) do
      {count, ""} when count in @counts -> {:noreply, resize(socket, count)}
      _unoffered -> {:noreply, socket}
    end
  end

  def handle_event("load_card", %{"card_id" => id}, socket) do
    case load(id) do
      {:ok, card} ->
        # The loaded card decides where the toggles sit, not the other way
        # round: its ID already carries the answer.
        {:noreply,
         assign(socket,
           cards: [card],
           count: 1,
           current: 0,
           symbols: card.symbols,
           pin_row: card.pin_row != nil,
           selection: nil,
           load_error: nil
         )}

      {:error, reason} ->
        {:noreply, assign(socket, load_error: load_error(reason))}
    end
  end

  def handle_event("select_cell", %{"row" => row, "col" => col}, socket) do
    spec = current_card(socket.assigns.cards, socket.assigns.current).spec

    case {index(row, spec.rows), index(col, spec.cols)} do
      {{:ok, row}, {:ok, col}} -> {:noreply, assign(socket, selection: {row, col})}
      _out_of_grid -> {:noreply, socket}
    end
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, selection: nil)}
  end

  # A cap, like `@counts`: unchecked, the reader would build a string of
  # whatever size the socket asked for.
  def handle_event("set_length", %{"length" => length}, socket) do
    case Integer.parse(to_string(length)) do
      {length, ""} when length in @lengths -> {:noreply, assign(socket, length: length)}
      _unoffered -> {:noreply, socket}
    end
  end

  def handle_event("set_direction", %{"direction" => direction}, socket) do
    case Compass.fetch(direction) do
      {:ok, direction} -> {:noreply, assign(socket, direction: direction)}
      :error -> {:noreply, socket}
    end
  end

  # `to_string/1` because a hand-rolled client can put a JSON number where the
  # browser would have sent a string.
  defp index(value, limit) do
    case Integer.parse(to_string(value)) do
      {index, ""} when index >= 0 and index < limit -> {:ok, index}
      _off_card -> :error
    end
  end

  defp current_card(cards, current), do: Enum.at(cards, current)

  defp deal(socket, symbols, pin_row) do
    count = socket.assigns.count

    assign(socket,
      cards: Run.deal(count, symbols: symbols, pin_row: pin_row),
      symbols: symbols,
      pin_row: pin_row,
      current: Stack.opens_at(count),
      selection: nil,
      load_error: nil
    )
  end

  defp resize(socket, count) do
    %{cards: cards, symbols: symbols, pin_row: pin_row} = socket.assigns

    assign(socket,
      cards: Run.resize(cards, count, symbols: symbols, pin_row: pin_row),
      count: count,
      current: Stack.opens_at(count)
    )
  end

  defp load(id) do
    cond do
      String.trim(id) == "" -> {:error, :blank}
      example_id?(id) -> {:error, :example_id}
      true -> Card.from_id(id)
    end
  end

  # Compared the way `Card.Id` reads an ID off paper, so every way of writing
  # the specimen counts as the specimen.
  defp example_id?(id), do: squash(id) == squash(@example_id)

  defp squash(id), do: id |> String.upcase() |> String.replace(~r/[^A-Z0-9]/, "")

  defp load_error(:blank), do: "Nothing filled in. Type the ID printed on your card."

  defp load_error(:example_id),
    do: "That one is just the example. Type the ID printed on your own card."

  defp load_error(:bad_checksum),
    do: "That doesn't look right. Check for a mistyped character."

  defp load_error(:unknown_version), do: "That card was made with a version we don't know."

  defp load_error(:bad_format), do: "That isn't a card ID. They look like #{@example_id}."

  # Derived at render rather than assigned in the handlers: four events move it,
  # and one forgetting would dim cells the password no longer runs through.
  defp trail(%{selection: nil}), do: MapSet.new()

  defp trail(%{selection: {row, col}} = assigns) do
    assigns.cards
    |> current_card(assigns.current)
    |> Card.trail(row, col, assigns.length, assigns.direction)
    |> MapSet.new()
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, trail: trail(assigns))

    ~H"""
    <div class="space-y-10">
      <div class="text-center space-y-3 print:hidden">
        <h1 class="text-4xl sm:text-5xl font-extrabold tracking-tight text-zinc-900 dark:text-zinc-100">
          Your passwords, on <span class="text-brand">paper*</span>
        </h1>
        <p :if={@format == :print} class="text-lg text-zinc-600 dark:text-zinc-300 max-w-2xl mx-auto">
          Print the card, keep it in your wallet. Pick an animal and an object, read off as many
          characters as you need.
        </p>
        <p :if={@format == :phone} class="text-lg text-zinc-600 dark:text-zinc-300 max-w-2xl mx-auto">
          The same card, turned upright for on your phone. Save it as an image, pick an animal and
          an object, read off as many characters as you need.
        </p>
      </div>

      <.format_switch format={@format} formats={formats()} />

      <%!-- `data-format` is here to be patched: without an attribute of its own
            that moves, swapping the stage's children would not reliably wake
            the hook. See `assets/js/hooks/card_stage.js`. --%>
      <div id="card-stage" phx-hook="CardStage" data-format={@format} data-card={@current}>
        <div :if={@format == :print} id="sheet">
          <div
            :for={{card, index} <- Enum.with_index(@cards)}
            class={[
              "card-slot stack-slot",
              index < @current && "stack-slot--peek stack-slot--above",
              index > @current && "stack-slot--peek stack-slot--below"
            ]}
            style={"z-index: #{Stack.depth(index, @current, length(@cards))}"}
          >
            <.card_table
              card={card}
              index={index}
              interactive={index == @current}
              selection={@selection}
              trail={@trail}
              mono={@mono}
            />
            <.stack_cover :if={index != @current} index={index} count={length(@cards)} />
          </div>
        </div>

        <.phone_card
          :if={@format == :phone}
          card={current_card(@cards, @current)}
          interactive={true}
          selection={@selection}
          trail={@trail}
        />
      </div>

      <.reader
        :if={@selection}
        card={current_card(@cards, @current)}
        selection={@selection}
        length={@length}
        direction={@direction}
        format={@format}
        lengths={lengths()}
      />

      <.controls
        load_error={@load_error}
        example_id={example_id()}
        symbols={@symbols}
        pin_row={@pin_row}
        mono={@mono}
        count={@count}
        format={@format}
        counts={counts()}
      />
      <.how_it_works format={@format} />

      <p class="text-sm text-zinc-500 dark:text-zinc-400 print:hidden">
        *Or any other medium really, get creative!
      </p>
    </div>
    """
  end

  # Handed to the components that draw them, so the handlers above validate
  # against the same lists.
  defp lengths, do: @lengths
  defp counts, do: @counts
  defp formats, do: @formats
  defp example_id, do: @example_id
end
