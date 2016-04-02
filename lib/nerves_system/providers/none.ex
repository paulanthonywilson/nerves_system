defmodule Nerves.System.Providers.None do
  use Nerves.System.Provider

  def cache_get(_system, _version, _config, _dest) do
    {:error, :nocache}
  end

  def compile(_system, _config, _dest) do
    {:error, :nocompile}
  end
end
