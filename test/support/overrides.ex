defmodule AshAuthentication.Phoenix.Test.Overrides do
  @moduledoc false
  use AshAuthentication.Phoenix.Overrides

  override AshAuthentication.Phoenix.SignInLive do
    set :redirect_param_name, "return_to"
  end
end
