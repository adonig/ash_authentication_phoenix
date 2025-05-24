defmodule AshAuthentication.Phoenix.LiveAuthFlowTest do
  @moduledoc false
  use AshAuthentication.Phoenix.Test.ConnCase

  test "unauthenticated user is redirected to sign-in and back to original page after login", %{
    conn: conn
  } do
    # Step 1: Accessing a protected LiveView without authentication → triggers redirect to /sign-in
    {:error, {:redirect, %{to: sign_in_url}}} = live(conn, "/protected")

    assert sign_in_url =~ "/sign-in"
    assert sign_in_url =~ "next=%2Fprotected"

    # Step 2: Register a user or ensure the user exists
    strategy = AshAuthentication.Info.strategy!(Example.Accounts.User, :password)
    email = "testuser@example.com"
    password = "secure123"
    create_user!(strategy, email, password)

    # Step 3: Simulate visiting the sign-in page with a redirect param (`next=/protected`)
    {:ok, lv, _html} = live(conn, ~p"/sign-in?next=/protected")

    # Submit the login form → should trigger a redirect to the token-based login URL
    {:error, {:redirect, %{to: token_url}}} =
      lv
      |> form(~s{[action="/auth/user/password/sign_in?"]},
        user: %{strategy.identity_field => email, strategy.password_field => password},
        redirect_param_name: "next",
        next: "/protected"
      )
      |> render_submit()

    # Follow the redirect to the token URL → should finally redirect to the original /protected path
    conn = get(build_conn(), token_url)
    assert redirected_to(conn, 302) == "/protected"
  end

  test "authenticated user accesses protected liveview directly", %{conn: conn} do
    strategy = AshAuthentication.Info.strategy!(Example.Accounts.User, :password)
    email = "sign.in.live@email"
    password = "sign.in.secret"
    create_user!(strategy, email, password)
    conn = sign_in_user(conn, strategy, email, password)

    {:ok, _view, html} = live(conn, "/protected")
    assert html =~ "Protected Content"
  end

  test "unauthenticated user can access /sign-in-no-user guarded by :live_no_user", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/sign-in-no-user")
    assert html =~ "Sign in"
  end

  test "authenticated user accessing /sign-in-no-user is redirected to /", %{conn: conn} do
    strategy = AshAuthentication.Info.strategy!(Example.Accounts.User, :password)
    email = "already.signed.in@example.com"
    password = "test12345"
    create_user!(strategy, email, password)
    conn = sign_in_user(conn, strategy, email, password)

    {:error, {:redirect, %{to: redirect}}} = live(conn, "/sign-in-no-user")
    assert redirect == "/"
  end

  test "authenticated user accessing /sign-in-no-user?next=/dashboard is redirected to /dashboard",
       %{
         conn: conn
       } do
    strategy = AshAuthentication.Info.strategy!(Example.Accounts.User, :password)
    email = "redirected@example.com"
    password = "test12345"
    create_user!(strategy, email, password)
    conn = sign_in_user(conn, strategy, email, password)

    conn = get(conn, "/sign-in-no-user", %{"next" => "/dashboard"})
    {:error, {:redirect, %{to: redirect}}} = live(conn)
    assert redirect == "/dashboard"
  end

  test "unauthenticated user can access optional page", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/optional")
    assert html =~ "Optional Content"
    assert html =~ "Please log in to see personalized info."
  end

  test "authenticated user can access optional page", %{conn: conn} do
    strategy = AshAuthentication.Info.strategy!(Example.Accounts.User, :password)
    email = "optional@example.com"
    password = "pass12345"
    create_user!(strategy, email, password)
    conn = sign_in_user(conn, strategy, email, password)

    {:ok, _view, html} = live(conn, "/optional")
    assert html =~ "Optional Content"
    assert html =~ "Welcome #{email}"
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
