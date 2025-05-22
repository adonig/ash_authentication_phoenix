defmodule AshAuthentication.Phoenix.LiveAuthFlowTest do
  @moduledoc false
  use AshAuthentication.Phoenix.Test.ConnCase

  test "unauthenticated user is redirected to sign-in and back to original page after login", %{
    conn: conn
  } do
    # Schritt 1: Zugriff auf geschützte LiveView ohne Login → Redirect zu /sign-in
    {:error, {:redirect, %{to: sign_in_url}}} = live(conn, "/protected")

    assert sign_in_url =~ "/sign-in"
    assert sign_in_url =~ "next=%2Fprotected"

    # Schritt 2: User registrieren oder sicherstellen, dass er existiert
    strategy = AshAuthentication.Info.strategy!(Example.Accounts.User, :password)
    email = "testuser@example.com"
    password = "secure123"
    create_user!(strategy, email, password)

    # Schritt 3: Simuliere Login mit next=/protected
    {:ok, lv, _html} = live(conn, ~p"/sign-in?next=/protected")

    {:error, {:redirect, %{to: token_url}}} =
      lv
      |> form(~s{[action="/auth/user/password/sign_in?"]},
        user: %{strategy.identity_field => email, strategy.password_field => password},
        redirect_param_name: "next",
        next: "/protected"
      )
      |> render_submit()

    conn = get(build_conn(), token_url)
    assert redirected_to(conn, 302) == "/protected"
  end

  test "authenticated user accesses protected liveview directly", %{conn: conn} do
    strategy = AshAuthentication.Info.strategy!(Example.Accounts.User, :password)
    email = "sign.in@email"
    password = "sign.in.secret"
    create_user!(strategy, email, password)
    conn = sign_in_user(conn, strategy, email, password)

    {:ok, _view, html} = live(conn, "/protected")
    assert html =~ "Protected Content"
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
