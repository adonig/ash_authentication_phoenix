defmodule AshAuthentication.Phoenix.Router.Routes.AuthFor do
  @moduledoc """
  Handles authentication strategy routes generation for a specific resource.

  This module generates explicit routes for each authentication strategy configured
  on a given AshAuthentication resource. Unlike `Routes.Auth` which uses a catch-all
  forward route, this module creates individual routes for each strategy phase.

  ## Route Structure

  For each strategy on the resource, generates routes like:

  ```
  scope "/authentication" do
    post "/password/register", AuthController, {:user, :password, :register}
    post "/password/sign_in", AuthController, {:user, :password, :sign_in}
    get "/oauth2/:name/request", AuthController, {:user, :oauth2, :request}
    get "/oauth2/:name/callback", AuthController, {:user, :oauth2, :callback}
    # ... etc for each strategy
  end
  ```

  ## Required Options

  * `:to` - A module which implements the `AshAuthentication.Phoenix.Controller` 
    behaviour. This is required.

  ## Optional Options

  * `:path` - A string (starting with "/") where to mount the generated routes.
    Defaults to the configured `default_auth_scope` (typically `/auth`).

  * `:scope_opts` - Any options to pass to the generated scope, such as host
    constraints or other Phoenix scope options.

  ## Examples

      # Basic usage
      auth_routes_for User, to: AuthController

      # Custom path
      auth_routes_for User,
        to: AuthController,
        path: "/authentication"

      # With scope options for subdomain
      auth_routes_for User,
        to: AuthController,
        path: "/auth",
        scope_opts: [host: "auth.example.com"]

      # Inside a scoped block
      scope "/api", MyAppWeb do
        auth_routes_for User,
          to: AuthController,
          path: "/v1/auth"
      end

  ## Comparison with auth_routes/3

  While `auth_routes/3` creates a catch-all forward route that dynamically
  handles multiple resources, `auth_routes_for/2` generates explicit routes
  for a single resource. Choose based on your needs:

  - Use `auth_routes/3` when you want dynamic routing for multiple resources
  - Use `auth_routes_for/2` when you want explicit routes for a single resource

  ## Controller Implementation

  The controller specified in the `:to` option must implement callbacks for
  each strategy phase. The controller actions receive a tuple of
  `{subject_name, strategy_name, phase}` as the action parameter.

  Example:

  ```elixir
  defmodule MyAppWeb.AuthController do
    use MyAppWeb, :controller
    use AshAuthentication.Phoenix.Controller

    def password_register(conn, {:user, :password, :register}) do
      # Handle password registration
    end
  end
  ```
  """

  @typedoc """
  Options that can be passed to auth_routes_for/2
  """
  @type auth_for_opts :: [
          {:to, module()}
          | {:path, String.t()}
          | {:scope_opts, keyword()}
        ]

  @typedoc """
  Configuration map returned by process_options/3 containing all
  processed options for building authentication routes for a specific resource.
  """
  @type auth_for_config :: %{
          required(:controller) => module(),
          required(:path) => String.t(),
          required(:scope_opts) => keyword(),
          required(:strategies) => list(AshAuthentication.Strategy.t()),
          required(:subject_name) => atom()
        }

  @doc """
  Builds the authentication routes macro expansion for a specific resource.

  This macro generates explicit routes for each strategy and phase combination
  configured on the resource. Each route maps to a specific controller action
  with strategy information passed as parameters.
  """
  defmacro build_route(module, resource, opts) do
    quote location: :keep do
      cfg =
        AshAuthentication.Phoenix.Router.Routes.AuthFor.process_options(
          unquote(module),
          unquote(resource),
          unquote(opts)
        )

      scope cfg.path, cfg.scope_opts do
        for strategy <- cfg.strategies do
          for {path, phase} <- AshAuthentication.Strategy.routes(strategy) do
            match AshAuthentication.Strategy.method_for_phase(strategy, phase),
                  path,
                  cfg.controller,
                  {cfg.subject_name, AshAuthentication.Strategy.name(strategy), phase},
                  as: :auth,
                  private: %{strategy: strategy}
          end
        end
      end
    end
  end

  @doc """
  Processes the options passed to auth_routes_for/2 and returns a configuration map.

  This function extracts the controller, path, and scope options, then retrieves
  all configured strategies from the resource to generate routes for each one.
  The subject name is also extracted for use in controller actions.
  """
  @spec process_options(module(), Ash.Resource.t(), auth_for_opts()) :: auth_for_config()
  def process_options(module, resource, opts) do
    alias AshAuthentication.Phoenix.Router.Options

    config = AshAuthentication.Phoenix.Router.get_config(module)
    default_path = Keyword.fetch!(config, :default_auth_scope)

    subject_name = AshAuthentication.Info.authentication_subject_name!(resource)
    controller = Keyword.fetch!(opts, :to)

    {path, opts} = Options.extract_option(opts, :path, default_path)
    scope_opts = Options.build_scope_opts(opts)

    strategies =
      AshAuthentication.Info.authentication_add_ons(resource) ++
        AshAuthentication.Info.authentication_strategies(resource)

    %{
      controller: controller,
      path: Options.ensure_path_prefix(path),
      scope_opts: scope_opts,
      strategies: strategies,
      subject_name: subject_name
    }
  end
end
