defmodule AshAuthentication.Phoenix.Utils.Redirect do
  @moduledoc """
  Utilities for safely handling user-provided redirect paths.
  Prevents open redirect vulnerabilities and infinite redirect loops.
  """

  @default_fallback "/"
  @default_unsafe_paths [
    "/auth",
    "/password-reset",
    "/reset",
    "/register",
    "/sign-in",
    "/sign-out"
  ]
  @default_safe_schemes [nil, "http", "https"]
  @default_safe_hosts [nil, "localhost", "127.0.0.1"]

  @doc """
  Sanitizes a potentially user-provided redirect path.

  Returns the path if it is safe. Otherwise, returns a fallback path.

  ## Options

    * `:fallback` - The fallback path to use if input is unsafe (default: `"/"`)
    * `:unsafe_paths` - Additional paths to consider unsafe
    * `:safe_schemes` - Schemes to allow in addition to `http` and `https`
    * `:safe_hosts` - Hosts to allow in addition to `localhost` and `127.0.0.1`

  ## Examples

      iex> sanitize_path("/dashboard")
      "/dashboard"

      iex> sanitize_path("https://evil.com", fallback: "/home")
      "/home"

      iex> sanitize_path("/custom", fallback: "/home", unsafe_paths: ["/custom"])
      "/home"

      iex> sanitize_path("ftp://localhost/", safe_schemes: ["ftp"])
      "ftp://localhost/"

      iex> sanitize_path("https://docs.myapp.com", safe_hosts: ["docs.myapp.com"])
      "https://docs.myapp.com"
  """
  @spec sanitize_path(String.t(), keyword()) :: String.t()
  def sanitize_path(path, opts \\ [])

  def sanitize_path(path, opts) when is_binary(path) and is_list(opts) do
    fallback = Keyword.get(opts, :fallback, @default_fallback)
    unsafe_paths = Keyword.get(opts, :unsafe_paths, []) ++ @default_unsafe_paths
    safe_schemes = Keyword.get(opts, :safe_schemes, []) ++ @default_safe_schemes
    safe_hosts = Keyword.get(opts, :safe_hosts, []) ++ @default_safe_hosts

    uri = URI.parse(path)

    cond do
      uri.path in unsafe_paths -> fallback
      String.starts_with?(path, "//") -> fallback
      uri.scheme not in safe_schemes -> fallback
      uri.host not in safe_hosts -> fallback
      true -> path
    end
  end
end
