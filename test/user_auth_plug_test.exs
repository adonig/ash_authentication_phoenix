defmodule AshAuthentication.Phoenix.Test.UserAuthPlugTest do
  use AshAuthentication.Phoenix.Test.ConnCase, async: true

  describe "require_user/2" do
    test "redirects to sign-in if no user", %{conn: conn} do
      conn = conn |> get(~p"/require-user/")
      assert redirected_to(conn) =~ "/sign-in?next=/require-user/"
      assert conn.halted
    end

    test "passes through if user is present", %{conn: conn} do
      strategy = AshAuthentication.Info.strategy!(Example.Accounts.User, :password)
      email = "require.user@email"
      password = "require.user.secret"
      create_user!(strategy, email, password)
      conn = sign_in_user(conn, strategy, email, password)

      conn = conn |> get(~p"/require-user/")
      refute conn.halted
    end
  end

  describe "no_user/2" do
    test "passes through if no user", %{conn: conn} do
      conn = conn |> get(~p"/no-user/")
      refute conn.halted
    end

    test "redirects to sanitized next if user is present", %{conn: conn} do
      strategy = AshAuthentication.Info.strategy!(Example.Accounts.User, :password)
      email = "no.user@email"
      password = "no.user.secret"
      create_user!(strategy, email, password)
      conn = sign_in_user(conn, strategy, email, password)

      conn = get(conn, ~p"/no-user/")
      assert redirected_to(conn) == "/"
      assert conn.halted
    end
  end

  defp create_user!(strategy, email, password) do
    Example.Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      strategy.identity_field => email,
      strategy.password_field => password,
      strategy.password_confirmation_field => password
    })
    |> Ash.create!()
  end

  defp sign_in_user(conn, strategy, email, password) do
    {:ok, lv, _html} = live(conn, ~p"/sign-in")

    {:ok, conn} =
      lv
      |> form(~s{[action="/auth/user/password/sign_in?"]},
        user: %{
          strategy.identity_field => email,
          strategy.password_field => password
        }
      )
      |> render_submit()
      |> follow_redirect(conn)

    conn
  end
end
