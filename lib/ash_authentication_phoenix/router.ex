defmodule AshAuthentication.Phoenix.Router do
  @moduledoc """
  Phoenix route generation for AshAuthentication.

  Using this module imports the macros in this module and the plug functions
  from `AshAuthentication.Phoenix.Plug`.

  ## Usage

  Adding authentication to your live-view router is very simple:

  ```elixir
  defmodule MyAppWeb.Router do
    use MyAppWeb, :router
    use AshAuthentication.Phoenix.Router,
      sign_in_path: "/sign-in",
      sign_out_path: "/sign-out", 
      reset_path: "/password-reset",
      default_auth_scope: "/auth"

    pipeline :browser do
      # ...
      plug(:load_from_session)
    end

    pipeline :api do
      # ...
      plug(:load_from_bearer)
    end

    scope "/", MyAppWeb do
      pipe_through :browser
      sign_in_route auth_routes_prefix: "/auth"
      sign_out_route AuthController
      auth_routes_for MyApp.Accounts.User, to: AuthController
      reset_route auth_routes_prefix: "/auth"
    end
  ```
  """

  alias AshAuthentication.Phoenix.Router.Routes

  require Logger

  @typedoc "Options that can be passed to `auth_routes_for`."
  @type auth_route_options :: [path_option | to_option | scope_opts_option]

  @typedoc "A sub-path if required.  Defaults to `/auth`."
  @type path_option :: {:path, String.t()}

  @typedoc "The controller which will handle success and failure."
  @type to_option :: {:to, AshAuthentication.Phoenix.Controller.t()}

  @typedoc "Any options which should be passed to the generated scope."
  @type scope_opts_option :: {:scope_opts, keyword}

  @typedoc """
  Configuration options for AshAuthentication.Phoenix router setup.

  These options control the default paths, layouts, and LiveView modules used
  for authentication routes. All options are optional and have sensible defaults.
  """
  @type router_opts :: [
          {:sign_in_path, String.t()}
          | {:sign_out_path, String.t()}
          | {:reset_path, String.t()}
          | {:confirm_path_prefix, String.t()}
          | {:magic_sign_in_path_prefix, String.t()}
          | {:redirect_param_name, String.t()}
          | {:default_auth_scope, String.t()}
          | {:default_layout, {module, String.t()} | nil}
          | {:gettext_backend, {module, String.t()} | nil}
          | {:default_live_view_sign_in, module}
          | {:default_live_view_reset, module}
          | {:default_live_view_confirm, module}
          | {:default_live_view_magic_sign_in, module}
        ]

  @default_router_opts [
    sign_in_path: "/sign-in",
    sign_out_path: "/sign-out",
    reset_path: "/password-reset",
    confirm_path_prefix: "/",
    magic_sign_in_path_prefix: "/",
    redirect_param_name: "next",
    default_auth_scope: "/auth",
    default_layout: nil,
    gettext_backend: nil,
    default_live_view_sign_in: AshAuthentication.Phoenix.SignInLive,
    default_live_view_reset: AshAuthentication.Phoenix.ResetLive,
    default_live_view_confirm: AshAuthentication.Phoenix.ConfirmLive,
    default_live_view_magic_sign_in: AshAuthentication.Phoenix.MagicSignInLive
  ]

  @doc """
  Configures AshAuthentication.Phoenix routing in your Phoenix router.

  This macro sets up the necessary configuration and imports for authentication
  routes. It should be called in your router module with `use AshAuthentication.Phoenix.Router`.

  ## Options

    * `:sign_in_path` - Path for the sign-in route. Defaults to `"/sign-in"`.
    * `:sign_out_path` - Path for the sign-out route. Defaults to `"/sign-out"`.
    * `:reset_path` - Path for the password reset route. Defaults to `"/password-reset"`.
    * `:confirm_path_prefix` - Path prefix for confirmation routes. Defaults to `"/"`.
    * `:magic_sign_in_path_prefix` - Path prefix for magic link sign-in routes. Defaults to `"/"`.
    * `:redirect_param_name` - Query parameter name for post-auth redirects. Defaults to `"next"`.
    * `:default_auth_scope` - Default scope for authentication routes. Defaults to `"/auth"`.
    * `:default_layout` - Default layout for authentication pages as `{module, template}` tuple. Defaults to `nil`.
    * `:gettext_backend` - Gettext backend for internationalization as `{module, domain}` tuple. Defaults to `nil`.
    * `:default_live_view_sign_in` - Default LiveView module for sign-in. Defaults to `AshAuthentication.Phoenix.SignInLive`.
    * `:default_live_view_reset` - Default LiveView module for password reset. Defaults to `AshAuthentication.Phoenix.ResetLive`.
    * `:default_live_view_confirm` - Default LiveView module for confirmation. Defaults to `AshAuthentication.Phoenix.ConfirmLive`.
    * `:default_live_view_magic_sign_in` - Default LiveView module for magic link sign-in. Defaults to `AshAuthentication.Phoenix.MagicSignInLive`.

  ## Example

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        use AshAuthentication.Phoenix.Router,
          sign_in_path: "/login",
          sign_out_path: "/logout",
          gettext_backend: {MyAppWeb.Gettext, "default"}

        # Your routes...
        sign_in_route()
        sign_out_route()
      end

  ## What it does

  This macro:
    * Stores the configuration as module attributes
    * Imports routing macros like `sign_in_route/1`, `sign_out_route/1`, etc.
    * Imports authentication plugs
    * Imports LiveSession helpers for authentication scoping
  """
  @spec __using__(opts :: router_opts()) :: Macro.t()
  defmacro __using__(opts) do
    quote bind_quoted: [opts: Keyword.merge(@default_router_opts, opts)] do
      # Store config as a module attribute so that all macros can read it.
      Module.register_attribute(__MODULE__, :ash_auth_config, accumulate: false)
      @ash_auth_config opts

      # Public helper for external modules (mainly needed at compile-time).
      def __ash_auth_config__, do: @ash_auth_config

      # Bring in routing helpers.
      import AshAuthentication.Phoenix.Router
      import AshAuthentication.Phoenix.Plug
      import AshAuthentication.Phoenix.LiveSession, only: :macros
    end
  end

  @doc """
  Retrieves the authentication configuration from the caller module.

  This function is used internally by the router macros to access the configuration
  options that were set when `use AshAuthentication.Phoenix.Router` was called.

  ## Parameters

   * `caller_module` - The module from which to retrieve the configuration.
     Typically this is `__CALLER__.module` from within a macro.

  ## Returns

  Returns a keyword list containing the authentication configuration options,
  or an empty list if no configuration is found.
  """
  @spec get_config(module()) :: keyword()
  def get_config(caller_module),
    do: Module.get_attribute(caller_module, :ash_auth_config) || []

  @doc """
  Generates explicit authentication routes for a specific resource.
  See `AshAuthentication.Phoenix.Router.Routes.AuthFor` for detailed documentation
  and available options.
  """
  @spec auth_routes_for(
          resource :: Ash.Resource.t(),
          opts :: Routes.AuthFor.auth_for_opts()
        ) :: Macro.t()
  defmacro auth_routes_for(resource, opts) when is_list(opts) do
    caller = __CALLER__.module

    quote do
      require AshAuthentication.Phoenix.Router.Routes.AuthFor

      AshAuthentication.Phoenix.Router.Routes.AuthFor.build_route(
        unquote(caller),
        unquote(resource),
        unquote(opts)
      )
    end
  end

  @doc """
  Generates the authentication routes.

  See `AshAuthentication.Phoenix.Router.Routes.Auth` for detailed documentation
  and available options.
  """
  @spec auth_routes(
          auth_controller :: module(),
          resource_or_resources :: Ash.Resource.t() | list(Ash.Resource.t()),
          opts :: Routes.Auth.auth_route_opts()
        ) :: Macro.t()
  defmacro auth_routes(auth_controller, resource_or_resources, opts \\ []) when is_list(opts) do
    caller = __CALLER__.module

    resources =
      resource_or_resources
      |> List.wrap()
      |> Enum.map(&Macro.expand_once(&1, %{__CALLER__ | function: {:auth_routes, 2}}))

    quote do
      require AshAuthentication.Phoenix.Router.Routes.Auth

      AshAuthentication.Phoenix.Router.Routes.Auth.build_route(
        unquote(caller),
        unquote(auth_controller),
        unquote(resources),
        unquote(opts)
      )
    end
  end

  @doc """
  Generates a sign-in route.

  See `AshAuthentication.Phoenix.Router.Routes.SignIn` for detailed documentation
  and available options.
  """
  @spec sign_in_route(Routes.SignIn.sign_in_route_opts()) :: Macro.t()
  defmacro sign_in_route(opts \\ []) do
    caller = __CALLER__.module

    quote do
      require AshAuthentication.Phoenix.Router.Routes.SignIn

      AshAuthentication.Phoenix.Router.Routes.SignIn.build_route(
        unquote(caller),
        unquote(opts)
      )
    end
  end

  @doc """
  Generates a sign-out route.

  See `AshAuthentication.Phoenix.Router.Routes.SignOut` for detailed documentation
  and available options.
  """
  @spec sign_out_route(AshAuthentication.Phoenix.Controller.t()) :: Macro.t()
  @spec sign_out_route(AshAuthentication.Phoenix.Controller.t(), String.t() | nil) :: Macro.t()
  @spec sign_out_route(AshAuthentication.Phoenix.Controller.t(), String.t() | nil, keyword()) ::
          Macro.t()
  defmacro sign_out_route(auth_controller, path \\ nil, opts \\ []) do
    caller = __CALLER__.module

    quote do
      require AshAuthentication.Phoenix.Router.Routes.SignOut

      AshAuthentication.Phoenix.Router.Routes.SignOut.build_route(
        unquote(caller),
        unquote(auth_controller),
        unquote(path),
        unquote(opts)
      )
    end
  end

  @doc """
  Generates a password reset route.

  See `AshAuthentication.Phoenix.Router.Routes.Reset` for detailed documentation
  and available options.
  """
  @spec reset_route(opts :: Routes.Reset.reset_route_opts()) :: Macro.t()
  defmacro reset_route(opts \\ []) do
    caller = __CALLER__.module

    quote do
      require AshAuthentication.Phoenix.Router.Routes.Reset

      AshAuthentication.Phoenix.Router.Routes.Reset.build_route(
        unquote(caller),
        unquote(opts)
      )
    end
  end

  @doc """
  Generates a confirmation route.

  See `AshAuthentication.Phoenix.Router.Routes.Confirm` for detailed documentation
  and available options.
  """
  @spec confirm_route(
          resource :: Ash.Resource.t(),
          strategy :: atom(),
          opts :: Routes.Confirm.confirm_route_opts()
        ) :: Macro.t()
  defmacro confirm_route(resource, strategy, opts \\ []) do
    caller = __CALLER__.module

    quote do
      require AshAuthentication.Phoenix.Router.Routes.Confirm

      AshAuthentication.Phoenix.Router.Routes.Confirm.build_route(
        unquote(caller),
        unquote(resource),
        unquote(strategy),
        unquote(opts)
      )
    end
  end

  @doc """
  Generates a magic link sign-in route.

  See `AshAuthentication.Phoenix.Router.Routes.MagicSignIn` for detailed documentation
  and available options.
  """
  @spec magic_sign_in_route(
          resource :: Ash.Resource.t(),
          strategy :: atom(),
          opts :: Routes.MagicSignIn.magic_sign_in_route_opts()
        ) :: Macro.t()
  defmacro magic_sign_in_route(resource, strategy, opts \\ []) do
    caller = __CALLER__.module

    quote do
      require AshAuthentication.Phoenix.Router.Routes.MagicSignIn

      AshAuthentication.Phoenix.Router.Routes.MagicSignIn.build_route(
        unquote(caller),
        unquote(resource),
        unquote(strategy),
        unquote(opts)
      )
    end
  end

  @doc false
  def generate_session(conn, session) do
    session
    |> Map.put("tenant", Ash.PlugHelpers.get_tenant(conn))
    |> Map.put("context", Ash.PlugHelpers.get_context(conn))
  end
end
