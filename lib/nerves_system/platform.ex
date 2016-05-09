defmodule Nerves.System.Platform do
  @callback config(system :: Nerves.Env.Dep.t, dest :: binary) ::
    :ok |
    {:error, error :: term}

  @callback bootstrap() ::
    {:ok, archive :: binary} |
    {:error, response :: term}

  defmacro __using__(_opts) do
    quote do
      @behaviour Nerves.System.Platform
      alias Nerves.System.Platform
    end
  end

  def build_config(%Nerves.Env.Dep{config: config}) do
    platform = config[:build_platform]
    Keyword.merge(platform.default_build_config, config[:build_config] || [])
  end
end
