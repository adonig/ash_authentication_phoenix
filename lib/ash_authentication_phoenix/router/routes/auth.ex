defmodule AshAuthentication.Phoenix.Router.Routes.Auth do
  @moduledoc """
  Handles authentication strategy routes generation for AshAuthentication.

  This module generates a catch-all route that handles various authentication strategies
  (OAuth, password authentication, etc.) for one or more AshAuthentication resources.
  It uses a plug-based router to dynamically handle different authentication paths.

  ## Route Structure

  The generated route creates a forward to a strategy router plug:

  ```
  scope "/" do
    forward "/auth", AshAuthentication.Phoenix.StrategyRouter,
      path: "/auth",
      as: :auth,
      controller: AuthController,
      resources: [User, Admin]
  end
  ```

  This will handle routes like:
  - `/auth/:resource/:strategy/request`
  - `/auth/:resource/:strategy/callback`
  - And other strategy-specific routes

  ## Important Routing Considerations

  This macro matches **all** routes at the provided path (default `/auth`). 
  If you have any other routes that begin with `/auth`, ensure this macro 
  appears after them in your router to avoid conflicts.

  ## Available Options

  * `:path` - The path to mount auth routes at. 
    Defaults to `/auth`. If changed, you should also update the 
    `auth_routes_prefix` option in `sign_in_route` to match.

  * `:not_found_plug` - A plug module to call if no matching route is found. 
    By default, it renders a simple JSON response with a 404 status code.

  * `:as` - The alias to use for the generated scope. 
    Defaults to `:auth`.

  * `:strategy_router_plug` - The plug module that handles strategy routing.
    Defaults to `AshAuthentication.Phoenix.StrategyRouter`.

  All other options are passed to the generated `scope`.

  ## Examples

      # Basic usage with a single resource
      auth_routes(MyAppWeb.AuthController, User)

      # Multiple resources
      auth_routes(MyAppWeb.AuthController, [User, Admin])

      # Custom path
      auth_routes(MyAppWeb.AuthController, User, path: "/authentication")

      # Custom not found handler
      auth_routes(MyAppWeb.AuthController, User,
        path: "/auth",
        not_found_plug: MyApp.Custom404Plug
      )

  ## Upgrading from auth_routes_for/2

  If you are using route helpers anywhere in your application (typically 
  `Routes.auth_path/3` or `Helpers.auth_path/3`), you will need to update 
  them to use verified routes. To see available routes, use:

      mix ash_authentication.phoenix.routes

  When using components from `AshAuthenticationPhoenix`, supply them with 
  the `auth_routes_prefix` assign, set to the path you provide here 
  (defaults to `/auth`).

  Also set `auth_routes_prefix` on the `reset_route`:

      reset_route(auth_routes_prefix: "/auth")

  ## Integration with Other Routes

  This route module works in conjunction with:
  - `sign_in_route` - Provides the UI for authentication
  - `sign_out_route` - Handles user logout
  - Strategy-specific routes for OAuth providers, magic links, etc.
  """

  @typedoc """
  Options that can be passed to auth_routes/3
  """
  @type auth_route_opts :: [
          {:path, String.t()}
          | {:not_found_plug, module() | nil}
          | {:as, atom()}
          | {:strategy_router_plug, module()}
          | {atom(), any()}
        ]

  @typedoc """
  Configuration map returned by process_options/2 containing all
  processed options for building authentication strategy routes.
  """
  @type auth_config :: %{
          required(:as) => atom(),
          required(:not_found_plug) => module() | nil,
          required(:path) => String.t(),
          required(:plug) => module(),
          required(:scope_opts) => keyword()
        }

  @doc """
  Builds the authentication routes macro expansion.

  This macro generates a forward route that delegates all authentication
  strategy handling to a plug-based router. The plug dynamically routes
  requests based on the resource and strategy in the URL path.
  """
  defmacro build_route(module, auth_controller, resources, opts) do
    quote location: :keep do
      cfg =
        AshAuthentication.Phoenix.Router.Routes.Auth.process_options(
          unquote(module),
          unquote(opts)
        )

      controller = Phoenix.Router.scoped_alias(__MODULE__, unquote(auth_controller))

      scope "/", cfg.scope_opts do
        forward cfg.path, cfg.plug,
          path: Phoenix.Router.scoped_path(__MODULE__, cfg.path),
          as: cfg.as,
          controller: controller,
          not_found_plug: cfg.not_found_plug,
          resources: unquote(resources)
      end
    end
  end

  @doc """
  Processes the options passed to auth_routes/3 and returns a configuration map.

  This function extracts routing options and configures the strategy router plug
  that will handle all authentication-related requests dynamically.
  """
  @spec process_options(module(), auth_route_opts()) :: auth_config()
  def process_options(module, opts) do
    alias AshAuthentication.Phoenix.Router.Options

    config = AshAuthentication.Phoenix.Router.get_config(module)
    default_path = Keyword.fetch!(config, :default_auth_scope)

    {as, opts} = Options.extract_option(opts, :as, :auth)
    {path, opts} = Options.extract_option(opts, :path, default_path)
    {not_found_plug, opts} = Options.extract_option(opts, :not_found_plug)

    {plug, opts} =
      Options.extract_option(
        opts,
        :strategy_router_plug,
        AshAuthentication.Phoenix.StrategyRouter
      )

    scope_opts = Options.build_scope_opts(opts)

    %{
      as: as,
      not_found_plug: not_found_plug,
      path: path,
      plug: plug,
      scope_opts: scope_opts
    }
  end
end
