defmodule AshAuthentication.Phoenix.Router.Routes.Confirm do
  @moduledoc """
  Handles confirmation route generation for AshAuthentication.

  This module generates routes for confirmation strategies that require user interaction
  (when `require_interaction?` is set to `true` on the strategy). It creates a 
  LiveView-based interface for handling confirmation flows such as email verification,
  account activation, or other custom confirmation requirements.

  ## Route Structure

  The generated routes create a live session with the following structure:

  ```
  scope "/confirm/email" do
    live_session :auth_confirm do
      live "/:token", ConfirmLive, :confirm  # if token_as_route_param? is true
      # or
      live "/", ConfirmLive, :confirm        # if token_as_route_param? is false
    end
  end
  ```

  ## Available Options

  * `:path` - The path under which to mount the live-view. 
    Defaults to `/confirm/<strategy>`.

  * `:token_as_route_param?` - Whether to use the token as a route parameter 
    (i.e., `<path>/:token`). Defaults to `true`.

  * `:live_view` - The name of the live view to render. 
    Defaults to `AshAuthentication.Phoenix.ConfirmLive`.

  * `:as` - Used to name the generated `live` route. 
    Defaults to `:auth`.

  * `:auth_routes_prefix` - Base path for authentication routes. If a tuple 
    `{:unscoped, path}` is provided, the path prefix will not inherit the current 
    route scope.

  * `:otp_app` - The OTP app to find authentication resources in. 
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

  All other options are passed to the generated `scope`.

  ## Examples

      # Basic usage
      confirm_route(User, :email)

      # Custom path without token in URL
      confirm_route(User, :account_activation,
        path: "/activate",
        token_as_route_param?: false
      )

      # Custom live view with translations
      confirm_route(User, :email_verification,
        live_view: MyApp.CustomConfirmLive,
        gettext_backend: {MyApp.Gettext, "auth"},
        as: :verify_email
      )

      # Unscoped path
      confirm_route(User, :email,
        auth_routes_prefix: {:unscoped, "/auth"}
      )
  """

  @typedoc """
  Options that can be passed to confirm_route/3
  """
  @type confirm_route_opts :: [
          {:path, String.t()}
          | {:token_as_route_param?, boolean()}
          | {:live_view, module}
          | {:as, atom}
          | {:on_mount, [module]}
          | {:overrides, [module]}
          | {:gettext_fn, {module, atom}}
          | {:gettext_backend, {module, String.t()}}
          | {:auth_routes_prefix, String.t() | {:unscoped, String.t()}}
          | {:otp_app, atom}
          | {:layout, {module, String.t()} | false}
          | {atom, any}
        ]

  @typedoc """
  Configuration map returned by process_options/4 containing all
  processed options for building a confirmation route.
  """
  @type confirm_config :: %{
          required(:as) => atom(),
          required(:gettext_backend) => {module(), String.t()} | nil,
          required(:live_session_opts) => keyword(),
          required(:live_view) => module(),
          required(:path) => String.t(),
          required(:scope_opts) => keyword()
        }

  @doc """
  Builds the confirmation route macro expansion.

  This macro generates the route structure including the scope, live session,
  and the live route for confirmation. The route can optionally include the 
  token as a route parameter.
  """
  defmacro build_route(module, resource, strategy, opts) do
    quote location: :keep do
      cfg =
        AshAuthentication.Phoenix.Router.Routes.Confirm.process_options(
          unquote(module),
          unquote(resource),
          unquote(strategy),
          unquote(opts)
        )

      scope cfg.path, cfg.scope_opts do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        live_session :"#{cfg.as}_confirm", cfg.live_session_opts do
          if Keyword.get(cfg.scope_opts, :token_as_route_param?, true) do
            live("/:token", cfg.live_view, :confirm, as: cfg.as)
          else
            live("/", cfg.live_view, :confirm, as: cfg.as)
          end
        end
      end

      case AshAuthentication.Phoenix.Router.Gettext.generate_fn(cfg.gettext_backend, cfg.path) do
        "" -> :ok
        fn_expr -> Code.eval_quoted(fn_expr, [], __ENV__)
      end
    end
  end

  @doc """
  Processes the options passed to confirm_route/3 and returns a configuration map.

  This function extracts all options, applies defaults from the router configuration,
  and transforms the options into a structured configuration map used by build_route/4.
  The resource and strategy parameters are included in the session data for use by
  the live view.
  """
  @spec process_options(module(), Ash.Resource.t(), atom(), confirm_route_opts()) ::
          confirm_config()
  def process_options(module, resource, strategy, opts) do
    alias AshAuthentication.Phoenix.Router.Options

    config = AshAuthentication.Phoenix.Router.get_config(module)
    default_path_prefix = Keyword.fetch!(config, :confirm_path_prefix)
    default_path = "#{default_path_prefix}#{strategy}"
    default_live_view = Keyword.fetch!(config, :default_live_view_confirm)

    # Extract route-specific options
    {path, opts} = Options.extract_option(opts, :path, default_path)
    {live_view, opts} = Options.extract_option(opts, :live_view, default_live_view)

    # Extract common LiveView options
    {common, remaining_opts} = Options.extract_live_view_options(opts, config)

    # Process values
    auth_routes_prefix = Options.process_path(common.auth_routes_prefix, module)

    gettext_fn =
      Options.process_gettext_fn(
        common.gettext_fn,
        common.gettext_backend,
        module,
        path
      )

    on_mount = Options.build_on_mount(common.on_mount_prepend, common.on_mount)
    scope_opts = Options.build_scope_opts(remaining_opts)

    # Build session params
    session_params = %{
      "auth_routes_prefix" => auth_routes_prefix,
      "overrides" => common.overrides,
      "gettext_fn" => gettext_fn,
      "resource" => resource,
      "strategy" => strategy,
      "otp_app" => common.otp_app
    }

    live_session_opts =
      Options.build_live_session_opts(
        session_params,
        on_mount,
        common.layout
      )

    %{
      as: common.as,
      gettext_backend: common.gettext_backend,
      live_session_opts: live_session_opts,
      live_view: live_view,
      path: path,
      scope_opts: scope_opts
    }
  end
end
