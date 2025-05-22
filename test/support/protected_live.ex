defmodule AshAuthentication.Phoenix.Test.ProtectedLive do
  use Phoenix.LiveView, layout: {AshAuthentication.Phoenix.Test.HomeLive, :live}

  def render(assigns) do
    ~H"""
    <h1>Protected Content</h1>
    """
  end
end
