defmodule Nerves.System.Platforms.BR do
  use Nerves.System.Platform
  alias Nerves.Env

  def bootstrap do
    Env.deps_by_type(:system_platform)
    |> List.first
    |> Map.get(:path)
    |> Path.join("nerves_env.exs")
    |> Code.require_file
  end
end
