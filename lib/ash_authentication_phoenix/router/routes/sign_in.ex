defmodule AshAuthentication.Phoenix.Router.Routes.SignIn do
  @moduledoc """
  Handles sign-in route generation for AshAuthentication.

  This module is responsible for building the sign-in routes, including optional
  registration and password reset routes. It generates a LiveView-based authentication
  interface using the components from `AshAuthentication.Phoenix.Components`.

  ## Route Structure

  The generated routes create a live session with the following structure:

  ```
  scope "/" do
    live_session :auth_sign_in do
      live "/sign-in", SignInLive, :sign_in
      live "/sign-in", SignInLive, :reset     # if reset_path is set
      live "/register", SignInLive, :register  # if register_path is set
    end
  end
  ```

  ## Available Options

  * `:path` - The path under which to mount the sign-in live-view. 
    Defaults to `/sign-in` within the current router scope.

  * `:auth_routes_prefix` - Base path for authentication routes. Used instead of route 
    helpers when determining routes. Allows disabling `helpers: true`. If a tuple 
    `{:unscoped, path}` is provided, the path prefix will not inherit the current 
    route scope. Defaults to `/auth`.

  * `:register_path` - The path under which to mount the password strategy's registration 
    live-view. If not set and registration is supported, registration will use a dynamic 
    toggle and will not be routeable to. If a tuple `{:unscoped, path}` is provided, 
    the registration path will not inherit the current route scope.

  * `:reset_path` - The path under which to mount the password strategy's password reset 
    live-view, for a user to request a reset token by email. If not set and password 
    reset is supported, password reset will use a dynamic toggle and will not be 
    routeable to. If a tuple `{:unscoped, path}` is provided, the reset path will not 
    inherit the current route scope.

  * `:resources` - Which resources should have their sign in UIs rendered. 
    Defaults to all resources that use `AshAuthentication`.

  * `:live_view` - The name of the live view to render. 
    Defaults to `AshAuthentication.Phoenix.SignInLive`.

  * `:as` - Used to prefix the generated `live_session` and `live` route names. 
    Defaults to `:auth`.

  * `:otp_app` - The OTP app or apps to find authentication resources in. 
    Pulls from the socket by default.

  * `:overrides` - Specify any override modules for customisation. 
    See `AshAuthentication.Phoenix.Overrides` for more information.
    Defaults to `[AshAuthentication.Phoenix.Overrides.Default]`.

  * `:gettext_fn` - A `{module, function}` tuple pointing to a translation function
    with the signature `(msgid :: String.t(), bindings :: keyword) :: String.t()`. 
    This function will be called to translate each output text of the live view.

  * `:gettext_backend` - A `{module, domain}` tuple pointing to a Gettext backend 
    module and specifying the Gettext domain. This is a convenience wrapper around 
    `:gettext_fn`.

  * `:layout` - The layout to use for the live views. Can be `{module, template}` 
    or `false`. Defaults to the router configuration.

  * `:on_mount` - Additional `on_mount` hooks to add to the live session.
    The authentication hooks are always included.

  * `on_mount_prepend` - Same as `on_mount`, but for hooks that need to be run
    before AshAuthenticationPhoenix's hooks.

  All other options are passed to the generated `scope`.

  ## Examples

      # Basic usage
      sign_in_route()

      # Custom paths
      sign_in_route(
        path: "/login",
        register_path: "/signup",
        reset_path: "/forgot-password"
      )

      # With unscoped paths
      sign_in_route(
        auth_routes_prefix: {:unscoped, "/auth"},
        register_path: {:unscoped, "/register"}
      )

      # Custom live view and translations
      sign_in_route(
        live_view: MyApp.CustomSignInLive,
        gettext_backend: {MyApp.Gettext, "auth"},
        as: :user_auth
      )
  """

  @typedoc """
  Options that can be passed to sign_in_route/1
  """
  @type sign_in_route_opts :: [
          {:path, String.t()}
          | {:live_view, module}
          | {:as, atom}
          | {:on_mount, [module]}
          | {:on_mount_prepend, [module]}
          | {:overrides, [module]}
          | {:gettext_fn, {module, atom}}
          | {:gettext_backend, {module, String.t()}}
          | {:auth_routes_prefix, String.t() | {:unscoped, String.t()}}
          | {:register_path, String.t() | {:unscoped, String.t()}}
          | {:reset_path, String.t() | {:unscoped, String.t()}}
          | {:otp_app, atom}
          | {:resources, [module]}
          | {:layout, {module, String.t()} | false}
          | {atom, any}
        ]

  @typedoc """
  Configuration map returned by process_options/2 containing all
  processed options for building a sign-in route.
  """
  @type sign_in_config :: %{
          required(:as) => atom(),
          required(:gettext_backend) => {module(), String.t()} | nil,
          required(:live_session_opts) => keyword(),
          required(:live_view) => module(),
          required(:path) => String.t(),
          required(:register_path) => String.t() | nil,
          required(:reset_path) => String.t() | nil,
          required(:scope_opts) => keyword()
        }

  @doc """
  Builds the sign-in route macro expansion.

  This macro generates the actual route structure including the scope,
  live session, and individual live routes for sign-in, registration,
  and password reset.
  """
  defmacro build_route(module, opts) do
    quote location: :keep do
      conf =
        AshAuthentication.Phoenix.Router.Routes.SignIn.process_options(
          unquote(module),
          unquote(opts)
        )

      scope "/", conf.scope_opts do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        live_session :"#{conf.as}_sign_in", conf.live_session_opts do
          live(conf.path, conf.live_view, :sign_in, as: conf.as)

          if conf.reset_path do
            live(conf.reset_path, conf.live_view, :reset, as: :"#{conf.as}_reset")
          end

          if conf.register_path do
            live(conf.register_path, conf.live_view, :register, as: :"#{conf.as}_register")
          end
        end
      end

      case AshAuthentication.Phoenix.Router.Gettext.generate_fn(conf.gettext_backend, conf.path) do
        "" -> :ok
        fn_expr -> Code.eval_quoted(fn_expr, [], __ENV__)
      end
    end
  end

  @doc """
  Processes the options passed to sign_in_route/1 and returns a configuration map.

  This function extracts all options, applies defaults from the router configuration,
  and transforms the options into a structured configuration map used by build_route/2.
  """
  @spec process_options(module(), sign_in_route_opts()) :: sign_in_config()
  def process_options(module, opts) do
    alias AshAuthentication.Phoenix.Router.Options

    config = AshAuthentication.Phoenix.Router.get_config(module)
    default_path = Keyword.fetch!(config, :sign_in_path)
    default_live_view = Keyword.fetch!(config, :default_live_view_sign_in)

    # Extract route-specific options
    {path, opts} = Options.extract_option(opts, :path, default_path)
    {live_view, opts} = Options.extract_option(opts, :live_view, default_live_view)
    {resources, opts} = Keyword.pop(opts, :resources)
    {reset_path, opts} = Keyword.pop(opts, :reset_path)
    {register_path, opts} = Keyword.pop(opts, :register_path)

    # Extract common LiveView options
    {common, remaining_opts} = Options.extract_live_view_options(opts, config)

    # Process values
    auth_routes_prefix = Options.process_path(common.auth_routes_prefix, module)
    register_path = Options.process_path(register_path, module)
    reset_path = Options.process_path(reset_path, module)
    sign_in_path = Phoenix.Router.scoped_path(module, path)

    gettext_fn =
      Options.process_gettext_fn(common.gettext_fn, common.gettext_backend, module, path)

    on_mount = Options.build_on_mount(common.on_mount_prepend, common.on_mount)
    scope_opts = Options.build_scope_opts(remaining_opts)

    # Build session params
    session_params = %{
      "overrides" => common.overrides,
      "auth_routes_prefix" => auth_routes_prefix,
      "otp_app" => common.otp_app,
      "resources" => resources,
      "path" => sign_in_path,
      "reset_path" => reset_path,
      "register_path" => register_path,
      "gettext_fn" => gettext_fn
    }

    live_session_opts = Options.build_live_session_opts(session_params, on_mount, common.layout)

    %{
      as: common.as,
      gettext_backend: common.gettext_backend,
      live_session_opts: live_session_opts,
      live_view: live_view,
      path: path,
      register_path: register_path,
      reset_path: reset_path,
      scope_opts: scope_opts
    }
  end
end
