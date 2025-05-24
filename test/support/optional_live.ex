defmodule AshAuthentication.Phoenix.Test.OptionalLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <h1>Optional Content</h1>
    <%= if @current_user do %>
      <p>Welcome {Ash.CiString.value(@current_user.email)}</p>
    <% else %>
      <p>Please log in to see personalized info.</p>
    <% end %>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
