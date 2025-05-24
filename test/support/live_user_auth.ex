defmodule AshAuthentication.Phoenix.Test.LiveUserAuth do
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: AshAuthentication.Phoenix.Test.Endpoint,
    router: AshAuthentication.Phoenix.Test.Router

  alias Phoenix.LiveView

  def on_mount(:live_user_optional, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:cont, LiveView.attach_hook(socket, :redirect, :handle_params, &redirect_to_sign_in/3)}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, LiveView.attach_hook(socket, :redirect, :handle_params, &redirect_to_next/3)}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  defp redirect_to_sign_in(_params, uri, socket) do
    # No need to sanitize, because the sign-in page will sanitize the next param internally.
    request_path = URI.parse(uri) |> Map.get(:path)
    {:halt, LiveView.redirect(socket, to: ~p"/sign-in?next=#{request_path}")}
  end

  defp redirect_to_next(params, _uri, socket) do
    # Sanitize the target path before redirecting to prevent open redirect attacks.
    next = Map.get(params, "next", "/")
    sanitized = AshAuthentication.Phoenix.Utils.Redirect.sanitize_path(next)

    IO.inspect(params, label: "Params in :live_no_user")
    IO.inspect(next, label: "Raw next param")
    IO.inspect(sanitized, label: "Sanitized redirect target")

    {:halt, LiveView.redirect(socket, to: sanitized)}
  end
end
