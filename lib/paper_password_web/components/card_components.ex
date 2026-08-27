defmodule PaperPasswordWeb.CardComponents do
  @moduledoc """
  A card, drawn: `card_table/1` for the wallet, `phone_card/1` transposed for a
  screen.

  A cell is `{animal_row, object_col}` in both, so `phx-click` sends the card's
  own coordinates and the LiveView never learns which view was on screen. Print
  geometry lives in `assets/css/print.css`.
  """
  use PaperPasswordWeb, :html

  alias PaperPassword.Card

  # ~17% grey. Lighter than this and a laser dithers the band into a speckle.
  # Kept in step with the dark-mode band in `assets/css/card.css`.
  @mono_band "#d4d4d4"
  @mono_accent "#000000"

  attr :card, Card, required: true
  attr :index, :integer, required: true
  attr :interactive, :boolean, required: true
  attr :selection, :any, required: true
  attr :trail, :any, required: true
  attr :mono, :boolean, required: true

  @doc "The wallet card: animals down, objects across."
  def card_table(assigns) do
    ~H"""
    <section
      id={"card-#{@index}"}
      class={[
        "card rounded-2xl border border-zinc-200 dark:border-zinc-700 bg-white dark:bg-zinc-900 p-2 sm:p-6 shadow-sm overflow-x-auto print:border-black print:shadow-none print:p-2",
        @mono && "card--mono"
      ]}
    >
      <table class="w-full border-collapse font-mono text-[11px] sm:text-base">
        <caption class="sr-only">
          Password card {@card.id}. Rows are labelled with animals, columns with objects.
        </caption>
        <%!-- Under `table-layout: fixed` columns are sized from the first row
              unless a `<col>` says otherwise. See `.label-column` in
              print.css. --%>
        <colgroup>
          <col class="label-column" />
          <col :for={_label <- @card.col_labels} />
        </colgroup>
        <thead>
          <tr>
            <th class="w-5 sm:w-8"><span class="sr-only">Row</span></th>
            <th
              :for={label <- @card.col_labels}
              scope="col"
              class="px-0 sm:px-0.5 pb-1 sm:pb-2 text-center text-sm sm:text-lg font-normal leading-none"
              title={label.name}
            >
              <span role="img" aria-label={label.name}>{label.char}</span>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            :for={{row_label, row_index} <- Enum.with_index(@card.row_labels)}
            class="row-band"
            style={row_style(@mono, row_label, row_index)}
          >
            <th
              scope="row"
              class="pr-1 sm:pr-2 text-center text-sm sm:text-lg font-normal leading-none border-l-4"
              style="border-color: var(--row-accent)"
              title={row_label.name}
            >
              <span role="img" aria-label={row_label.name}>{row_label.char}</span>
            </th>
            <td
              :for={{char, col_index} <- Enum.with_index(Enum.at(@card.grid, row_index))}
              class={[
                "px-0 sm:px-0.5 py-0.5 sm:py-1 text-center tabular-nums select-none",
                @interactive && "cursor-pointer hover:bg-brand/10 print:hover:bg-transparent",
                @interactive && highlight(@selection, @trail, row_index, col_index)
              ]}
              phx-click={@interactive && "select_cell"}
              phx-value-row={@interactive && row_index}
              phx-value-col={@interactive && col_index}
            >
              {char}
            </td>
          </tr>
        </tbody>
      </table>

      <p
        id={"card-#{@index}-id"}
        class="card-id-line mt-4 text-xs text-center text-zinc-500 dark:text-zinc-400 font-mono"
      >
        {@card.id}
      </p>
    </section>
    """
  end

  attr :card, Card, required: true
  attr :interactive, :boolean, required: true
  attr :selection, :any, required: true
  attr :trail, :any, required: true

  @doc "The same card transposed: objects down the page, animals across it."
  def phone_card(assigns) do
    assigns =
      assign(assigns,
        rows:
          assigns.card.col_labels
          |> Enum.zip(Enum.zip_with(assigns.card.grid, & &1))
          |> Enum.with_index()
      )

    ~H"""
    <section
      id="phone-card"
      data-card-id={@card.id}
      class="phone-card mx-auto w-full max-w-sm rounded-2xl border border-zinc-200 dark:border-zinc-700 bg-white dark:bg-zinc-900 p-3 shadow-sm"
    >
      <table class="w-full border-collapse font-mono text-sm">
        <caption class="sr-only">
          Password card {@card.id}, upright. Columns are labelled with animals, rows with objects.
        </caption>
        <colgroup>
          <col class="phone-label-column" />
          <col
            :for={label <- @card.row_labels}
            class="col-band"
            style={"--row-tint: #{label.tint}; --row-accent: #{label.color}"}
          />
        </colgroup>
        <thead>
          <tr>
            <th><span class="sr-only">Object</span></th>
            <%!-- Read back by `assets/js/card_image.js`, which draws the saved
                  PNG from this table rather than a second copy of the grid. --%>
            <th
              :for={label <- @card.row_labels}
              scope="col"
              data-animal
              data-tint={label.tint}
              data-accent={label.color}
              class="pb-1 text-center text-xl font-normal leading-none border-b-4"
              style={"border-color: #{label.color}"}
              title={label.name}
            >
              <span role="img" aria-label={label.name}>{label.char}</span>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr :for={{{col_label, cells}, col_index} <- @rows}>
            <th
              scope="row"
              class="pr-1 text-center text-lg font-normal leading-none"
              title={col_label.name}
            >
              <span role="img" aria-label={col_label.name}>{col_label.char}</span>
            </th>
            <td
              :for={{char, row_index} <- Enum.with_index(cells)}
              class={[
                "px-0.5 py-1 text-center tabular-nums select-none",
                @interactive && "cursor-pointer hover:bg-brand/30",
                @interactive && highlight(@selection, @trail, row_index, col_index)
              ]}
              phx-click={@interactive && "select_cell"}
              phx-value-row={@interactive && row_index}
              phx-value-col={@interactive && col_index}
            >
              {char}
            </td>
          </tr>
        </tbody>
      </table>

      <p class="card-id-line mt-3 text-xs text-center text-zinc-500 dark:text-zinc-400 font-mono">
        {@card.id}
      </p>
    </section>
    """
  end

  attr :index, :integer, required: true
  attr :count, :integer, required: true

  @doc """
  What you click to bring a card in the stack up.

  A button over the whole slice, so it is reachable by keyboard and covers the
  clipped grid underneath.
  """
  def stack_cover(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="show_card"
      phx-value-index={@index}
      aria-label={"Show card #{@index + 1} of #{@count}"}
      class="stack-cover absolute inset-0 w-full rounded-2xl hover:bg-brand/5 focus:outline-none focus:ring-2 focus:ring-brand print:hidden"
    />
    """
  end

  # Both palettes leave through the same two custom properties, so no rule that
  # paints a band needs to know which one it was handed.
  defp row_style(false, label, _index) do
    "--row-tint: #{label.tint}; --row-accent: #{label.color}"
  end

  defp row_style(true, _label, index) do
    tint = if rem(index, 2) == 0, do: "#ffffff", else: @mono_band
    "--row-tint: #{tint}; --row-accent: #{@mono_accent}"
  end

  # A `cond`, not two classes: the selected cell is also in its own trail, so
  # both would match and Tailwind's emission order would decide what you saw.
  defp highlight(selection, trail, row, col) do
    cond do
      selected?(selection, row, col) ->
        "bg-brand text-white rounded print:bg-transparent print:text-black"

      MapSet.member?(trail, {row, col}) ->
        "bg-brand/20 rounded print:bg-transparent"

      true ->
        nil
    end
  end

  defp selected?(nil, _row, _col), do: false
  defp selected?({row, col}, row, col), do: true
  defp selected?(_selection, _row, _col), do: false
end
