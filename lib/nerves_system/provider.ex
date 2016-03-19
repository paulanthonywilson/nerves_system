defmodule Nerves.System.Provider do
  @callback cache_get(system :: atom, version :: String.t, destination :: String.t) ::
    {:ok, archive :: binary} |
    {:error, response :: term}

  @callback compile(system :: atom, destination :: String.t) ::
    {:ok, archive :: binary} |
    {:error, response :: term}

  defmacro __using__(_opts) do
    quote do
      @behaviour Nerves.System.Provider
      alias Nerves.System.Provider
    end
  end

  def shell_info(text), do: Mix.shell.info "[nerves_system]#{text}"

end
