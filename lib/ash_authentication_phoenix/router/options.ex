defmodule AshAuthentication.Phoenix.Router.Options do
  @moduledoc """
  Common option processing utilities for AshAuthentication router macros.

  This module provides shared functionality for processing options across
  different route types, reducing duplication and ensuring consistency.
  """

  @typedoc """
  Common options that appear across multiple route types.
  Used for documentation purposes.
  """
  @type common_opts :: [
          {:as, atom()}
          | {:otp_app, atom()}
          | {:layout, {module(), String.t()} | false}
          | {:on_mount, [module()]}
          | {:on_mount_prepend, [module()]}
          | {:auth_routes_prefix, String.t() | {:unscoped, String.t()}}
          | {:gettext_fn, {module(), atom()}}
          | {:gettext_backend, {module(), String.t()}}
          | {:overrides, [module()]}
        ]

  @doc """
  Extracts common LiveView options from the options keyword list.

  Returns a tuple of `{extracted_options_map, remaining_opts}`.

  ## Extracted Options

  The following options are extracted if present:
  - `:as` - Route alias (defaults to `:auth`)
  - `:otp_app` - OTP application
  - `:layout` - Layout configuration
  - `:on_mount` - Additional on_mount hooks
  - `:on_mount_prepend` - Additional on_mount_prepend hooks
  - `:auth_routes_prefix` - Authentication routes prefix
  - `:gettext_fn` - Custom gettext function
  - `:gettext_backend` - Gettext backend configuration
  - `:overrides` - Override modules

  ## Example

      iex> extract_live_view_options([as: :user, path: "/auth"], config)
      {%{as: :user, layout: nil, ...}, [path: "/auth"]}
  """
  @spec extract_live_view_options(keyword(), keyword()) :: {map(), keyword()}
  def extract_live_view_options(opts, config) do
    default_layout = Keyword.get(config, :default_layout)
    default_gettext_backend = Keyword.get(config, :gettext_backend)

    {as, opts} = Keyword.pop(opts, :as, :auth)
    {otp_app, opts} = Keyword.pop(opts, :otp_app)
    {layout, opts} = Keyword.pop(opts, :layout, default_layout)
    {on_mount, opts} = Keyword.pop(opts, :on_mount)
    {on_mount_prepend, opts} = Keyword.pop(opts, :on_mount_prepend)
    {auth_routes_prefix, opts} = Keyword.pop(opts, :auth_routes_prefix)
    {gettext_fn, opts} = Keyword.pop(opts, :gettext_fn)
    {gettext_backend, opts} = Keyword.pop(opts, :gettext_backend, default_gettext_backend)

    {overrides, opts} =
      Keyword.pop(opts, :overrides, [AshAuthentication.Phoenix.Overrides.Default])

    extracted = %{
      as: as,
      otp_app: otp_app,
      layout: layout,
      on_mount: on_mount,
      on_mount_prepend: on_mount_prepend,
      auth_routes_prefix: auth_routes_prefix,
      gettext_fn: gettext_fn,
      gettext_backend: gettext_backend,
      overrides: overrides
    }

    {extracted, opts}
  end

  @doc """
  Processes path options, handling both regular and unscoped paths.

  ## Examples

      iex> process_path("/auth", MyRouter)
      "/my_scope/auth"
      
      iex> process_path({:unscoped, "/auth"}, MyRouter)
      "/auth"
      
      iex> process_path(nil, MyRouter)
      nil
  """
  @spec process_path(String.t() | {:unscoped, String.t()} | nil, module()) :: String.t() | nil
  def process_path(nil, _module), do: nil
  def process_path({:unscoped, value}, _module), do: value
  def process_path(value, module), do: Phoenix.Router.scoped_path(module, value)

  @doc """
  Builds the on_mount configuration for LiveView routes.

  Ensures required authentication hooks are included and deduplicates entries.
  """
  @spec build_on_mount([module()] | nil, [module()] | nil) :: [module()]
  def build_on_mount(on_mount_prepend, custom_on_mount) do
    on_mount_prepend = on_mount_prepend || []
    custom_on_mount = custom_on_mount || []

    (on_mount_prepend ++
       [
         AshAuthentication.Phoenix.Router.OnLiveViewMount,
         AshAuthentication.Phoenix.LiveSession | custom_on_mount
       ])
    |> Enum.uniq_by(fn
      {mod, _} -> mod
      mod -> mod
    end)
  end

  @doc """
  Builds live session options with common configuration.

  ## Parameters

  - `session_params` - Map of parameters to pass to the session generator
  - `on_mount` - List of on_mount hooks
  - `layout` - Layout configuration (can be nil)
  """
  @spec build_live_session_opts(map(), [module()], {module(), String.t()} | false | nil) ::
          keyword()
  def build_live_session_opts(session_params, on_mount, layout) do
    opts = [
      session: {AshAuthentication.Phoenix.Router, :generate_session, [session_params]},
      on_mount: on_mount
    ]

    case layout do
      nil -> opts
      layout -> Keyword.put(opts, :layout, layout)
    end
  end

  @doc """
  Builds scope options with common defaults.

  Sets `:alias` to `false` by default and merges any additional options.
  """
  @spec build_scope_opts(keyword(), keyword()) :: keyword()
  def build_scope_opts(opts, additional \\ []) do
    opts
    |> Keyword.put_new(:alias, false)
    |> Keyword.merge(additional)
  end

  @doc """
  Processes gettext function configuration.

  Delegates to the Gettext module's function pointer generator.
  """
  @spec process_gettext_fn(
          {module(), atom()} | nil,
          {module(), String.t()} | nil,
          module(),
          String.t()
        ) :: any()
  def process_gettext_fn(gettext_fn, gettext_backend, module, path) do
    AshAuthentication.Phoenix.Router.Gettext.maybe_generate_fn_pointer(
      gettext_fn,
      gettext_backend,
      module,
      path
    )
  end

  @doc """
  Extracts a single option with a default value.

  This is a simple wrapper around `Keyword.pop/3` for consistency.
  """
  @spec extract_option(keyword(), atom(), any()) :: {any(), keyword()}
  def extract_option(opts, key, default \\ nil) do
    Keyword.pop(opts, key, default)
  end

  @doc """
  Ensures a path string starts with "/".

  ## Examples

      iex> ensure_path_prefix("auth")
      "/auth"
      
      iex> ensure_path_prefix("/auth")
      "/auth"
  """
  @spec ensure_path_prefix(String.t()) :: String.t()
  def ensure_path_prefix(path) when is_binary(path) do
    AshAuthentication.Phoenix.Utils.String.ensure_prefix(path, "/")
  end
end
