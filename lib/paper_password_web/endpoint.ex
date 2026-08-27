defmodule PaperPasswordWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :paper_password

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_paper_password_key",
    signing_salt: "gL4Ba6E7",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  # `only` matches the first path segment, and digesting puts the hash inside
  # that segment for a file at the static root: favicon.svg is requested as
  # favicon-<hash>.svg. `only_matching` prefix-matches those. Drop it and the
  # favicons 404 in prod only, where the cache manifest is loaded.
  plug Plug.Static,
    at: "/",
    from: :paper_password,
    gzip: false,
    only: PaperPasswordWeb.static_paths(),
    only_matching: ~w(favicon robots)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug PaperPasswordWeb.Router
end
