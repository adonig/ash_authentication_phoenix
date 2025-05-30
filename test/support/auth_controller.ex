defmodule AshAuthentication.Phoenix.Test.AuthController do
  @moduledoc false

  use DevWeb, :controller
  use AshAuthentication.Phoenix.Controller

  @doc false
  @impl true
  def success(conn, _activity, user, _token) do
    conn = conn |> store_in_session(user) |> assign(:current_user, user)

    with name when not is_nil(name) <- conn.params["redirect_param_name"],
         value when not is_nil(value) <- conn.params[name] do
      conn
      |> redirect(to: value)
    else
      _ ->
        conn
        |> put_status(200)
        |> render("success.html")
    end
  end

  @doc false
  @impl true
  def failure(conn, _activity, reason) do
    conn
    |> assign(:failure_reason, reason)
    |> redirect(to: "/sign-in")
  end

  @doc false
  @impl true
  def sign_out(conn, _params) do
    conn
    |> clear_session()
    |> render(:signed_out)
  end
end
