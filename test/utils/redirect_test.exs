defmodule AshAuthenticationPhoenix.Utils.RedirectTest do
  use ExUnit.Case, async: true

  import AshAuthentication.Phoenix.Utils.Redirect, only: [sanitize_path: 1, sanitize_path: 2]

  doctest AshAuthentication.Phoenix.Utils.Redirect

  describe "sanitize_path/3" do
    test "returns safe local path" do
      assert sanitize_path("/dashboard") == "/dashboard"
    end

    test "blocks known unsafe paths" do
      assert sanitize_path("/sign-in") == "/"
      assert sanitize_path("/auth", fallback: "/home") == "/home"
    end

    test "blocks custom unsafe paths" do
      assert sanitize_path("/internal", unsafe_paths: ["/internal"]) == "/"
    end

    test "blocks external urls" do
      assert sanitize_path("https://evil.com") == "/"
      assert sanitize_path("http://example.com") == "/"
    end

    test "blocks protocol-relative urls" do
      assert sanitize_path("//example.com") == "/"
    end

    test "blocks unsupported schemes" do
      assert sanitize_path("ftp://localhost") == "/"
      assert sanitize_path("irc://localhost") == "/"
    end

    test "allows safe localhost urls" do
      assert sanitize_path("http://localhost", fallback: "/fallback") == "http://localhost"
    end

    test "allows relative paths like ./dashboard" do
      assert sanitize_path("./dashboard") == "./dashboard"
    end

    test "keeps trailing slashes" do
      assert sanitize_path("/dashboard/") == "/dashboard/"
    end

    test "preserves query strings for safe paths" do
      assert sanitize_path("/dashboard?tab=profile") == "/dashboard?tab=profile"
    end

    test "blocks paths starting with double slashes" do
      assert sanitize_path("///danger") == "/"
    end

    test "blocks external urls with uppercase scheme" do
      assert sanitize_path("HTTP://evil.com") == "/"
    end

    test "allows relative paths with .." do
      assert sanitize_path("../profile") == "../profile"
    end

    test "allows pure query strings" do
      assert sanitize_path("?admin=true") == "?admin=true"
    end

    test "blocks subdomains of localhost" do
      assert sanitize_path("http://localhost.evil.com") == "/"
    end
  end
end
