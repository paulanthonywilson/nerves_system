defmodule Nerves.System.Platform do
  @callback bootstrap() ::
    {:ok, archive :: binary} |
    {:error, response :: term}

  defmacro __using__(_opts) do
    quote do
      @behaviour Nerves.System.Platform
      alias Nerves.System.Platform
    end
  end
end
