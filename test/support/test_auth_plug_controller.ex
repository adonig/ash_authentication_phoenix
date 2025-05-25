defmodule AshAuthentication.Phoenix.Test.TestAuthPlugController do
  use Phoenix.Controller

  def require_user(conn, _params) do
    send_resp(conn, 200, "OK: authenticated")
  end

  def no_user(conn, _params) do
    send_resp(conn, 200, "OK: not authenticated")
  end
end
