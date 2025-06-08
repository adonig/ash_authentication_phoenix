defmodule AshAuthentication.Phoenix.Utils.String do
  def ensure_prefix(string, prefix) do
    if String.starts_with?(string, prefix), do: string, else: prefix <> string
  end
end
