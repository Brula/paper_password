defmodule PaperPasswordWeb.FlashComponents do
  @moduledoc """
  The two banners that show when the LiveView socket drops.

  LiveView puts `phx-client-error` or `phx-server-error` on the body when the
  connection goes, and without something listening for that a lost connection
  looks exactly like a page whose buttons have stopped working.

  There is nothing else here. This app never calls `put_flash/3`: there is
  nothing to log into and nothing to save. The generated `CoreComponents` this
  grew out of shipped modals, tables, forms and inputs it never had a use for.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Renders both connection banners, hidden until the socket says otherwise.

  ## Examples

      <.connection_banners />
  """
  def connection_banners(assigns) do
    ~H"""
    <div id="connection-banners">
      <.banner id="client-error" on=".phx-client-error" title="We can't find the internet">
        Attempting to reconnect <.spinner />
      </.banner>

      <.banner id="server-error" on=".phx-server-error" title="Something went wrong!">
        Hang in there while we get back on track <.spinner />
      </.banner>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :on, :string, required: true, doc: "the class LiveView puts on the body when it drops"
  attr :title, :string, required: true
  slot :inner_block, required: true

  # The selector names the body class and the banner both, because the class
  # lands on an ancestor rather than on the banner itself.
  defp banner(assigns) do
    ~H"""
    <div
      id={@id}
      role="alert"
      phx-disconnected={show("#{@on} ##{@id}")}
      phx-connected={hide("##{@id}")}
      hidden
      class="fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1 bg-rose-50 text-rose-900 shadow-md ring-rose-500 dark:bg-rose-950 dark:text-rose-100"
    >
      <p class="text-sm font-semibold leading-6">{@title}</p>
      <p class="mt-2 text-sm leading-5">{render_slot(@inner_block)}</p>
    </div>
    """
  end

  # Inline rather than a Heroicon. It is the only icon left in the app, and
  # carrying the whole heroicons dependency and its Tailwind plugin for one
  # 12px circle was not a trade worth making.
  defp spinner(assigns) do
    ~H"""
    <svg class="ml-1 inline h-3 w-3 animate-spin" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" opacity="0.25" />
      <path fill="currentColor" d="M12 2a10 10 0 0 1 10 10h-4a6 6 0 0 0-6-6V2z" />
    </svg>
    """
  end

  defp show(selector) do
    JS.show(
      to: selector,
      time: 300,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  defp hide(selector) do
    JS.hide(
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end
end
