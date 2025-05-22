defmodule AshAuthentication.Phoenix.Test.LiveUserAuth do
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: AshAuthentication.Phoenix.Test.Endpoint,
    router: AshAuthentication.Phoenix.Test.Router

  alias Phoenix.LiveView

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:cont, LiveView.attach_hook(socket, :redirect_and_halt, :handle_params, &hook/3)}
    end
  end

  defp hook(_params, uri, socket) do
    request_path = URI.parse(uri) |> Map.get(:path)
    socket = LiveView.redirect(socket, to: ~p"/sign-in?next=#{request_path}")
    {:halt, socket}
  end
end
