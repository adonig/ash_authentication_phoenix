defmodule AshAuthentication.Phoenix.Test.UserAuthPlug do
  @moduledoc false

  import AshAuthentication.Phoenix.Plug, only: [load_from_session: 2]
  alias Plug.Conn

  @doc """
  Requires a user to be authenticated. Otherwise redirects to sign-in.
  """
  @spec require_user(Conn.t(), keyword) :: Conn.t()
  def require_user(conn, opts) do
    conn = load_from_session(conn, opts)

    if conn.assigns[:current_user] do
      conn
    else
      # Use the config value here too
      param_name = Keyword.get(opts, :redirect_param_name, "next")
      sign_in_path = Keyword.get(opts, :sign_in_path, "/sign-in")
      redirect_path = "#{sign_in_path}?#{param_name}=#{conn.request_path}"

      Phoenix.Controller.redirect(conn, to: redirect_path)
      |> Plug.Conn.halt()
    end
  end

  @doc """
  If a user is authenticated, they are redirected away. Otherwise access is granted.
  """
  @spec no_user(Conn.t(), keyword) :: Conn.t()
  def no_user(conn, opts) do
    conn = load_from_session(conn, opts)

    if conn.assigns[:current_user] do
      next = Plug.Conn.get_req_header(conn, "next") |> List.first() || "/"

      Phoenix.Controller.redirect(conn,
        to: AshAuthentication.Phoenix.Utils.Redirect.sanitize_path(next)
      )
      |> Plug.Conn.halt()
    else
      conn
    end
  end
end
