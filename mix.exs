defmodule Nerves.System.Mixfile do
  use Mix.Project
  require Logger

  @cache_provider     System.get_env("NERVES_SYSTEM_CACHE_PROVIDER") || "bakeware"
  @compiler_provider  System.get_env("NERVES_SYSTEM_COMPILER_PROVIDER") || "bakeware"

  providers =
    HashSet.new
    |> HashSet.put(@cache_provider)
    |> HashSet.put(@compiler_provider)
    |> HashSet.to_list
    |> Enum.map(&String.to_atom/1)

  @providers providers

  def project do
    [app: :nerves_system,
     version: "0.0.1",
     elixir: "~> 1.2",
     deps: deps]
  end

  def application do
    [applications: []]
  end

  defp deps do
    Enum.reduce(@providers, [], fn(provider, acc) -> acc ++ provider(provider) end)
  end

  defp provider(:bakeware) do
    [{:bake, github: "bakeware/bake"}]
  end

  defp provider(:local) do
    [{:porcelain, "~> 2.0"}]
  end

  defp provider(_) do
    []
  end
end
