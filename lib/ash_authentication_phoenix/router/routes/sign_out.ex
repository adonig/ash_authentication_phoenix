defmodule AshAuthentication.Phoenix.Router.Routes.SignOut do
  @moduledoc """
  Handles sign-out route generation for AshAuthentication.

  This module generates a simple HTTP route that signs out the current user by
  calling the `:sign_out` action on your authentication controller. Unlike the
  other route modules that generate LiveView routes, this creates a standard
  Phoenix controller route.

  ## Route Structure

  The generated route creates a simple GET endpoint:

  ```
  scope "/sign-out" do
    get "/", AuthController, :sign_out, as: :auth
  end
  ```

  ## Available Options

  * `:as` - Used to name the generated route. 
    Defaults to `:auth`.

  All other options are passed to the generated `scope`.

  ## Examples

      # Basic usage with default path
      sign_out_route(MyAppWeb.AuthController)

      # Custom path
      sign_out_route(MyAppWeb.AuthController, "/logout")

      # Custom path with options
      sign_out_route(MyAppWeb.AuthController, "/logout", as: :logout)

      # Using nil path to fall back to default
      sign_out_route(MyAppWeb.AuthController, nil, as: :user_logout)

  ## Controller Implementation

  Your authentication controller should implement the `:sign_out` action.
  Typically, this action will:

  1. Clear the authentication tokens from the connection
  2. Redirect the user to an appropriate page (e.g., home or sign-in)

  Example controller implementation:

  ```elixir
  defmodule MyAppWeb.AuthController do
    use MyAppWeb, :controller
    use AshAuthentication.Phoenix.Controller

    def sign_out(conn, _params) do
      conn
      |> clear_session()
      |> redirect(to: ~p"/")
    end
  end
  ```
  """

  @typedoc """
  Options that can be passed to sign_out_route/3
  """
  @type sign_out_route_opts :: [
          {:as, atom}
          | {atom, any}
        ]

  @typedoc """
  Configuration map returned by process_options/3 containing all
  processed options for building a sign-out route.
  """
  @type sign_out_config :: %{
          required(:as) => atom(),
          required(:path) => String.t(),
          required(:scope_opts) => keyword()
        }

  @doc """
  Builds the sign-out route macro expansion.

  This macro generates a simple controller route that points to the `:sign_out`
  action of the specified authentication controller. Unlike other route modules,
  this generates a standard Phoenix route rather than a LiveView route.
  """
  defmacro build_route(module, auth_controller, path, opts) do
    quote location: :keep do
      cfg =
        AshAuthentication.Phoenix.Router.Routes.SignOut.process_options(
          unquote(module),
          unquote(path),
          unquote(opts)
        )

      scope cfg.path, cfg.scope_opts do
        get("/", unquote(auth_controller), :sign_out, as: cfg.as)
      end
    end
  end

  @doc """
  Processes the options passed to sign_out_route/3 and returns a configuration map.

  This is the simplest option processor in the router module family, as sign-out
  routes have minimal configuration needs. The path can be explicitly set or will
  fall back to the default from the router configuration.
  """
  @spec process_options(module(), String.t() | nil, sign_out_route_opts()) :: sign_out_config()
  def process_options(module, path, opts) do
    alias AshAuthentication.Phoenix.Router.Options

    config = AshAuthentication.Phoenix.Router.get_config(module)
    default_path = Keyword.fetch!(config, :sign_out_path)

    {as, scope_opts} = Options.extract_option(opts, :as, :auth)

    %{
      as: as,
      path: path || default_path,
      scope_opts: scope_opts
    }
  end
end
