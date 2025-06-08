defmodule AshAuthentication.Phoenix.Router.Routes.Reset do
  @moduledoc """
  Handles password reset route generation for AshAuthentication.

  This module generates the password reset page where users can set a new password
  after receiving a reset token. This is different from the reset request functionality
  (which is part of the sign-in route) - this page is where users actually change
  their password using a valid reset token.

  ## Route Structure

  The generated routes create a live session with the following structure:

  ```
  scope "/password-reset" do
    live_session :auth_reset do
      live "/:token", ResetLive, :reset
    end
  end
  ```

  Note that this route always requires a token parameter in the URL, as users
  must have a valid reset token to access the password reset form.

  ## Available Options

  * `:path` - The path under which to mount the live-view. 
    Defaults to `/password-reset`.

  * `:live_view` - The name of the live view to render. 
    Defaults to `AshAuthentication.Phoenix.ResetLive`.

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
      reset_route()

      # Custom path
      reset_route(path: "/reset-password")

      # Custom live view with translations
      reset_route(
        live_view: MyApp.CustomResetLive,
        gettext_backend: {MyApp.Gettext, "auth"},
        as: :password_reset
      )

      # Unscoped path
      reset_route(
        auth_routes_prefix: {:unscoped, "/auth"}
      )

  ## Integration with Sign-In Route

  This route works in conjunction with the `reset_path` option in `sign_in_route/1`.
  The typical flow is:

  1. User requests a password reset through the sign-in page (at the `reset_path`)
  2. System sends an email with a reset token
  3. User clicks the link and is directed to this reset route with the token
  4. User enters their new password on this page
  """

  @typedoc """
  Options that can be passed to reset_route/1
  """
  @type reset_route_opts :: [
          {:path, String.t()}
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
  Configuration map returned by process_options/2 containing all
  processed options for building a password reset route.
  """
  @type reset_config :: %{
          required(:as) => atom(),
          required(:gettext_backend) => {module(), String.t()} | nil,
          required(:live_session_opts) => keyword(),
          required(:live_view) => module(),
          required(:path) => String.t(),
          required(:scope_opts) => keyword()
        }

  @doc """
  Builds the password reset route macro expansion.

  This macro generates the route structure including the scope, live session,
  and the live route for password reset. The route always includes a token
  parameter as password reset requires a valid token.
  """
  defmacro build_route(module, opts) do
    quote location: :keep do
      cfg =
        AshAuthentication.Phoenix.Router.Routes.Reset.process_options(
          unquote(module),
          unquote(opts)
        )

      scope cfg.path, cfg.scope_opts do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        live_session :"#{cfg.as}_reset", cfg.live_session_opts do
          live("/:token", cfg.live_view, :reset, as: cfg.as)
        end
      end

      case AshAuthentication.Phoenix.Router.Gettext.generate_fn(cfg.gettext_backend, cfg.path) do
        "" -> :ok
        fn_expr -> Code.eval_quoted(fn_expr, [], __ENV__)
      end
    end
  end

  @doc """
  Processes the options passed to reset_route/1 and returns a configuration map.

  This function extracts all options, applies defaults from the router configuration,
  and transforms the options into a structured configuration map used by build_route/2.
  Unlike routes that target specific resources/strategies, this route handles password
  resets across all configured resources.
  """
  @spec process_options(module(), reset_route_opts()) :: reset_config()
  def process_options(module, opts) do
    alias AshAuthentication.Phoenix.Router.Options

    config = AshAuthentication.Phoenix.Router.get_config(module)
    default_path = Keyword.fetch!(config, :reset_path)
    default_live_view = Keyword.fetch!(config, :default_live_view_reset)

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
