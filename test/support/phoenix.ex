defmodule AshAuthentication.Phoenix.Test.ErrorView do
  @moduledoc false
  @doc false
  def render(template, _), do: Phoenix.Controller.status_message_from_template(template)
end

defmodule AshAuthentication.Phoenix.Test.HomeLive do
  @moduledoc false
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :count, 0)}
  end

  defp phx_vsn, do: Application.spec(:phoenix, :vsn)
  defp lv_vsn, do: Application.spec(:phoenix_live_view, :vsn)

  @doc false
  def render("live.html", assigns) do
    ~H"""
    <script src={"https://cdn.jsdelivr.net/npm/phoenix@#{phx_vsn()}/priv/static/phoenix.min.js"}>
    </script>
    <script
      src={"https://cdn.jsdelivr.net/npm/phoenix_live_view@#{lv_vsn()}/priv/static/phoenix_live_view.min.js"}
    >
    </script>
    <script>
      let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket)
      liveSocket.connect()
    </script>
    <style>
      * { font-size: 1.1em; }
    </style>
    {@inner_content}
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    {@count}
    <button phx-click="inc">+</button>
    <button phx-click="dec">-</button>
    """
  end

  @impl true
  def handle_event("inc", _params, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count + 1)}
  end

  def handle_event("dec", _params, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count - 1)}
  end
end

defmodule AshAuthentication.Phoenix.Test.SuccessController do
  use Phoenix.Controller

  def index(conn, _params) do
    send_resp(conn, 200, "SUCCESS")
  end
end

defmodule AshAuthentication.Phoenix.Test.Router do
  @moduledoc false
  alias AshAuthentication.Phoenix.Test.ComponentsLive
  use Phoenix.Router
  import Phoenix.LiveView.Router
  use AshAuthentication.Phoenix.Router
  import AshAuthentication.Phoenix.Test.UserAuthPlug

  pipeline :browser do
    plug(:accepts, ["html"])
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers

    plug :load_from_session
    plug :put_test_context
  end

  scope "/", AshAuthentication.Phoenix.Test do
    pipe_through :browser

    sign_in_route register_path: "/register", reset_path: "/reset", auth_routes_prefix: "/auth"
    sign_out_route AuthController
    reset_route auth_routes_prefix: "/auth"

    auth_routes AuthController, Example.Accounts.User, path: "/auth"

    # Custom LiveView for components testing
    sign_in_route path: "/custom_lv",
                  auth_routes_prefix: "/auth",
                  live_view: ComponentsLive,
                  as: :custom_lv

    # Gettext routes
    sign_in_route path: "/anmeldung",
                  auth_routes_prefix: "/auth",
                  gettext_fn: {AshAuthentication.Phoenix.Test.Gettext, :translate_test},
                  as: :gettext

    reset_route path: "/vergessen",
                auth_routes_prefix: "/auth",
                gettext_fn: {AshAuthentication.Phoenix.Test.Gettext, :translate_test},
                as: :gettext

    sign_in_route path: "/anmeldung_backend",
                  auth_routes_prefix: "/auth",
                  gettext_backend: {AshAuthentication.Phoenix.Test.Gettext, "test"},
                  as: :gettext_backend

    reset_route path: "/vergessen_backend",
                auth_routes_prefix: "/auth",
                gettext_backend: {AshAuthentication.Phoenix.Test.Gettext, "test"},
                as: :gettext_backend

    # Sign-in with overridden redirect param name
    sign_in_route path: "/sign-in-return",
                  auth_routes_prefix: "/auth",
                  overrides: [AshAuthentication.Phoenix.Test.Overrides],
                  as: :return
  end

  scope "/nested", AshAuthentication.Phoenix.Test do
    pipe_through :browser

    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  as: :nested

    sign_out_route AuthController
    reset_route as: :nested
  end

  scope "/unscoped", AshAuthentication.Phoenix.Test do
    pipe_through :browser

    sign_in_route register_path: {:unscoped, "/register"},
                  reset_path: {:unscoped, "/reset"},
                  auth_routes_prefix: {:unscoped, "/auth"},
                  as: :unscoped

    sign_out_route AuthController
    reset_route as: :unscoped
  end

  scope "/", AshAuthentication.Phoenix.Test do
    pipe_through(:browser)

    live("/", HomeLive, :index)

    ash_authentication_live_session :optional_user,
      on_mount: {AshAuthentication.Phoenix.Test.LiveUserAuth, :live_user_optional} do
      live "/optional", OptionalLive, :index
    end

    ash_authentication_live_session :authentication_required,
      on_mount: {AshAuthentication.Phoenix.Test.LiveUserAuth, :live_user_required} do
      live "/protected", ProtectedLive, :index
    end

    sign_in_route(
      path: "/sign-in-no-user",
      auth_routes_prefix: "/auth",
      overrides: [AshAuthentication.Phoenix.Test.Overrides],
      on_mount: [{AshAuthentication.Phoenix.Test.LiveUserAuth, :live_no_user}],
      as: :return_sign_in
    )
  end

  scope "/require-user", AshAuthentication.Phoenix.Test do
    pipe_through [:browser, :require_user]

    get "/", SuccessController, :index
  end

  scope "/no-user", AshAuthentication.Phoenix.Test do
    pipe_through [:browser, :no_user]

    get "/", SuccessController, :index
  end

  @doc false
  def put_test_context(conn, _) do
    case Application.get_env(:ash_authentication_phoenix, :test_context) do
      nil -> conn
      context -> Ash.PlugHelpers.set_context(conn, context)
    end
  end
end

defmodule AshAuthentication.Phoenix.Test.Endpoint do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :ash_authentication_phoenix

  @session_options [
    store: :cookie,
    key: "_webuilt_key",
    signing_salt: "c911QDW5",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Session, @session_options
  plug(AshAuthentication.Phoenix.Test.Router)
end
