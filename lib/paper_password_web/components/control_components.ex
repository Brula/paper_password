defmodule PaperPasswordWeb.ControlComponents do
  @moduledoc """
  Everything on the page that is not the card itself.

  Every menu is passed in rather than declared here: `PaperPasswordWeb.HomeLive`
  validates against the same list it offers.
  """
  use PaperPasswordWeb, :html

  alias PaperPassword.Card
  alias PaperPasswordWeb.Compass

  attr :format, :atom, required: true
  attr :formats, :list, required: true

  @doc "Wallet card or phone screen."
  def format_switch(assigns) do
    ~H"""
    <fieldset class="flex items-center justify-center gap-1 print:hidden">
      <legend class="sr-only">Card format</legend>
      <div class="inline-flex rounded-lg border border-zinc-300 dark:border-zinc-600 p-1 gap-1">
        <button
          :for={{value, label} <- @formats}
          id={"format-#{value}"}
          type="button"
          phx-click="set_format"
          phx-value-format={value}
          aria-pressed={to_string(value == @format)}
          class={[
            "px-4 py-1.5 rounded-md text-sm font-medium transition",
            value == @format && "bg-brand text-white shadow-sm",
            value != @format &&
              "text-zinc-600 dark:text-zinc-300 hover:text-brand dark:hover:text-brand"
          ]}
        >
          {label}
        </button>
      </div>
    </fieldset>
    """
  end

  attr :card, Card, required: true
  attr :selection, :any, required: true
  attr :length, :integer, required: true
  attr :direction, :atom, required: true
  attr :format, :atom, required: true
  attr :lengths, :list, required: true

  @doc "The password a cell gives you, and the two dials that change it."
  def reader(assigns) do
    {row, col} = assigns.selection

    assigns =
      assign(assigns,
        password: Card.read(assigns.card, row, col, assigns.length, assigns.direction),
        row_label: Enum.at(assigns.card.row_labels, row),
        col_label: Enum.at(assigns.card.col_labels, col),
        compass: Compass.keys(assigns.format)
      )

    ~H"""
    <section class="rounded-2xl border border-zinc-200 dark:border-zinc-700 bg-zinc-50 dark:bg-zinc-800 p-6 space-y-4 print:hidden">
      <div class="flex items-start justify-between gap-4">
        <div>
          <p class="text-sm text-zinc-600 dark:text-zinc-300">
            Starting at <span role="img" aria-label={@row_label.name}>{@row_label.char}</span>
            {@row_label.name} + <span role="img" aria-label={@col_label.name}>{@col_label.char}</span>
            {@col_label.name}
          </p>
          <p class="mt-2 font-mono text-2xl break-all text-zinc-900 dark:text-zinc-100">
            {@password}
          </p>
        </div>
        <button
          phx-click="clear_selection"
          class="text-sm text-zinc-500 hover:text-brand shrink-0"
          type="button"
        >
          Clear
        </button>
      </div>

      <div class="space-y-2">
        <fieldset class="flex items-start gap-3">
          <legend class="sr-only">Password length</legend>
          <span class="w-20 shrink-0 pt-1.5 text-sm text-zinc-600 dark:text-zinc-300">
            Length
          </span>
          <div class="flex flex-wrap gap-1">
            <button
              :for={option <- @lengths}
              type="button"
              phx-click="set_length"
              phx-value-length={option}
              aria-pressed={to_string(option == @length)}
              class={key_class(option == @length)}
            >
              {option}
            </button>
          </div>
        </fieldset>

        <fieldset class="flex items-start gap-3">
          <legend class="sr-only">Reading direction</legend>
          <span class="w-20 shrink-0 pt-1.5 text-sm text-zinc-600 dark:text-zinc-300">
            Direction
          </span>
          <div class="grid grid-cols-4 gap-1 w-max">
            <button
              :for={{arrow, name, direction} <- @compass}
              type="button"
              phx-click="set_direction"
              phx-value-direction={direction}
              aria-label={name}
              aria-pressed={to_string(direction == @direction)}
              title={name}
              class={key_class(direction == @direction)}
            >
              {arrow}
            </button>
          </div>
        </fieldset>
      </div>

      <p class="text-xs text-zinc-500 dark:text-zinc-400">
        Try out some examples. Pick a length and a direction.
      </p>
    </section>
    """
  end

  attr :load_error, :any, required: true
  attr :example_id, :string, required: true
  attr :symbols, :boolean, required: true
  attr :pin_row, :boolean, required: true
  attr :mono, :boolean, required: true
  attr :count, :integer, required: true
  attr :format, :atom, required: true
  attr :counts, :list, required: true

  @doc "New cards, printing, the alphabet toggles, and the reprint form."
  def controls(assigns) do
    ~H"""
    <section class="space-y-4 print:hidden">
      <div class="flex flex-col sm:flex-row gap-4 sm:items-center">
        <button
          phx-click="new_card"
          type="button"
          class="rounded-lg bg-brand px-6 py-3 text-white font-semibold shadow hover:bg-brand/90 transition shrink-0"
        >
          {if @count == 1 or @format == :phone, do: "New card", else: "New cards"}
        </button>
        <button
          :if={@format == :print}
          id="print-card"
          type="button"
          class="rounded-lg border border-brand px-6 py-3 text-brand font-semibold hover:bg-brand/5 transition shrink-0"
        >
          {if @count == 1, do: "Print", else: "Print #{@count} cards"}
        </button>
        <button
          :if={@format == :phone}
          id="save-image"
          type="button"
          class="rounded-lg border border-brand px-6 py-3 text-brand font-semibold hover:bg-brand/5 transition shrink-0"
        >
          Save image
        </button>
        <%!-- The two print-only controls are `:if`d individually rather than
              wrapped, so the phone view reflows to one row of two instead of
              leaving an empty one behind. --%>
        <div class="grid grid-cols-2 items-center gap-x-6 gap-y-3 sm:ml-auto">
          <fieldset :if={@format == :print} class="flex flex-wrap items-center gap-1.5 sm:gap-2">
            <legend class="sr-only">How many cards</legend>
            <span class="text-sm text-zinc-600 dark:text-zinc-300">Cards</span>
            <button
              :for={option <- @counts}
              type="button"
              phx-click="set_count"
              phx-value-count={option}
              aria-pressed={to_string(option == @count)}
              class={[
                "px-2 sm:px-3 py-1 rounded text-sm border",
                option == @count && "bg-brand text-white border-brand",
                option != @count && "border-zinc-300 dark:border-zinc-600 hover:border-brand"
              ]}
            >
              {option}
            </button>
          </fieldset>
          <.toggle
            :if={@format == :print}
            id="mono-toggle"
            event="toggle_mono"
            on={@mono}
            label="Monochrome"
          />
          <.toggle
            id="symbols-toggle"
            event="toggle_symbols"
            on={@symbols}
            label="Special characters"
          />
          <.toggle
            id="pin-row-toggle"
            event="toggle_pin_row"
            on={@pin_row}
            label={if @format == :phone, do: "A column for PINs", else: "A row for PINs"}
          />
        </div>
      </div>

      <p :if={@format == :phone} class="text-sm text-zinc-500 dark:text-zinc-400">
        The image is drawn in your browser and downloaded straight to this device. It is never
        uploaded. Worth knowing what you are choosing, though: a card in your photo roll syncs,
        backs up and unlocks with your phone, and paper does none of those things.
      </p>

      <form phx-submit="load_card" class="space-y-2">
        <label for="card-id" class="block text-sm font-medium text-zinc-900 dark:text-zinc-100">
          Reprint an existing card
        </label>
        <div class="flex gap-2">
          <input
            type="text"
            id="card-id"
            name="card_id"
            placeholder={@example_id}
            autocomplete="off"
            spellcheck="false"
            class="flex-1 rounded-lg border-zinc-300 dark:border-zinc-600 dark:bg-zinc-800 font-mono text-sm"
          />
          <button
            type="submit"
            class="rounded-lg border border-zinc-300 dark:border-zinc-600 px-4 text-sm font-semibold hover:border-brand transition shrink-0"
          >
            Load
          </button>
        </div>
        <p :if={@load_error} class="text-sm text-red-600 dark:text-red-400">
          {@load_error}
        </p>
      </form>
    </section>
    """
  end

  attr :format, :atom, required: true

  @doc "The instructions at the bottom of the page."
  def how_it_works(assigns) do
    ~H"""
    <section id="how-it-works" class="space-y-4 print:hidden">
      <h2 class="text-2xl font-bold text-zinc-900 dark:text-zinc-100">How it works</h2>
      <ol class="space-y-3 text-zinc-600 dark:text-zinc-300 list-decimal list-inside">
        <li :if={@format == :print}>
          Print the card and keep it somewhere you can always find it.
        </li>
        <li :if={@format == :phone}>
          Save the image and keep it where you can always find it.
        </li>
        <li>
          For each site, pick a starting cell you'll remember: an animal and an object.
          Bank could be <span role="img" aria-label="pig">🐷</span>
          + <span role="img" aria-label="key">🔑</span>.
        </li>
        <li>
          Pick a direction and an amount of steps, or get creative, and there's your password.
        </li>
        <li :if={@format == :print}>
          Printing more than one gives you that many <em>different</em>
          cards, not copies. Flip through the deck to see each one; every card has its own ID.
        </li>
        <li :if={@format == :phone}>
          Need more than one? Press New card and save the image again.
        </li>
      </ol>
      <p class="text-zinc-600 dark:text-zinc-300">
        Make sure to keep track of the card's ID somewhere. You can reload it here as long as you have the ID.
        Without it, losing your card means losing your passwords, cause every card is unique.
      </p>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :event, :string, required: true
  attr :on, :boolean, required: true
  attr :label, :string, required: true

  defp toggle(assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <button
        id={@id}
        type="button"
        role="switch"
        phx-click={@event}
        aria-checked={to_string(@on)}
        aria-labelledby={"#{@id}-label"}
        class={[
          "relative h-6 w-11 shrink-0 rounded-full transition focus:outline-none focus:ring-2 focus:ring-brand focus:ring-offset-2 dark:focus:ring-offset-zinc-900",
          @on && "bg-brand",
          !@on && "bg-zinc-300 dark:bg-zinc-600"
        ]}
      >
        <span class={[
          "block h-5 w-5 rounded-full bg-white shadow transition-transform",
          @on && "translate-x-[1.375rem]",
          !@on && "translate-x-0.5"
        ]} />
      </button>
      <span
        id={"#{@id}-label"}
        class="text-sm leading-tight font-medium text-zinc-900 dark:text-zinc-100"
      >
        {@label}
      </span>
    </div>
    """
  end

  # A fixed box, not padding: "8", "20" and "↘" are three widths, and the two
  # rows of keys only line up if none of them gets a say.
  defp key_class(pressed?) do
    [
      "h-8 w-10 flex items-center justify-center rounded border text-sm leading-none",
      pressed? && "bg-brand text-white border-brand",
      !pressed? && "border-zinc-300 dark:border-zinc-600 hover:border-brand"
    ]
  end
end
