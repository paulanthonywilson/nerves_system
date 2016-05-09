defmodule Nerves.System.Mixfile do
  use Mix.Project
  require Logger

  default_cache = "http"

  default_compiler =
    case :os.type do
      {_, :linux} -> "local"
      _ -> "none"
    end

  @cache      System.get_env("NERVES_SYSTEM_CACHE")    || default_cache
  @compiler   System.get_env("NERVES_SYSTEM_COMPILER") || default_compiler

  providers = [@cache, @compiler]
  |> Enum.map(&String.to_atom/1)
  |> Enum.uniq

  @providers providers

  System.put_env("NERVES_SYSTEM_CACHE", @cache)
  System.put_env("NERVES_SYSTEM_COMPILER", @compiler)

  def project do
    [app: :nerves_system,
     version: "0.1.0",
     elixir: "~> 1.2",
     description: description,
     package: package,
     deps: deps]
  end

  def application do
    [applications: []]
  end

  defp deps do
    Enum.reduce(@providers, [], fn(provider, acc) -> acc ++ provider(provider) end)
  end

  defp provider(:http) do
    [{:httpoison, "~> 0.8.3"}]
  end

  defp provider(:local) do
    [{:porcelain, "~> 2.0"}]
  end

  defp provider(_) do
    []
  end

  defp description do
    """
    Elixir compilers and scripts for building Nerves Systems. For useable system configurations see nerves_system_*
    """
  end

  defp package do
    [maintainers: ["Frank Hunleth", "Justin Schneck"],
     files: ["lib", "README.md", "LICENSE", "nerves.exs", "mix.exs"],
     licenses: ["Apache 2.0"],
     links: %{"Github" => "https://github.com/nerves-project/nerves_system"}]
  end

end
