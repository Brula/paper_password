defmodule PaperPasswordWeb.Router do
  use PaperPasswordWeb, :router

  # Everything the app needs comes from our own origin: one stylesheet, one
  # script, and the LiveView socket. Nothing is fetched from a CDN, so the
  # policy can stay at 'self' throughout.
  #
  # `style-src` is the one exception. The card tints each row from the palette in
  # `Card.Emoji` through a `style` attribute, and a browser treats those the same
  # as an inline `<style>` block. Scripts are the part that matters here and they
  # stay locked down; an injected style cannot execute.
  #
  # `connect-src 'self'` covers the WebSocket: CSP3 matches ws:// and wss:// on
  # the page's own origin against 'self'.
  @csp """
  default-src 'self'; \
  base-uri 'self'; \
  form-action 'self'; \
  frame-ancestors 'none'; \
  object-src 'none'; \
  img-src 'self' data:; \
  script-src 'self'; \
  style-src 'self' 'unsafe-inline'; \
  connect-src 'self'\
  """

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PaperPasswordWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # Kept off `:browser` because LiveDashboard serves inline scripts that it
  # expects to nonce per request, which a static header cannot do. Only the
  # dev-only dashboard scope below skips this; every public route carries it.
  pipeline :csp do
    plug :put_secure_browser_headers, %{"content-security-policy" => @csp}
  end

  scope "/", PaperPasswordWeb do
    pipe_through [:browser, :csp]

    live "/", HomeLive, :index
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:paper_password, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PaperPasswordWeb.Telemetry
    end
  end
end
