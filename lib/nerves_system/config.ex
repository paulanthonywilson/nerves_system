defmodule Nerves.System.Config do

  def start do
    Agent.start_link fn -> [] end, name: __MODULE__
  end

  def load(config_file) do
    config =
      config_file
      |> File.open!
      |> IO.stream(:line)
      |> Stream.map(& String.strip/1)
      |> Stream.reject(& String.starts_with?(&1, "#"))
      |> Stream.map(& String.split(&1, "="))
      |> Keyword.new(fn
        ([k, v]) ->
          {String.to_atom(k), v}
      end)
    Agent.update(__MODULE__, &(Keyword.merge(&1, config)))
  end

  def dump do
    Agent.get(__MODULE__, &(&1))
    |> Enum.map(fn ({k, v}) -> "#{k}=#{v}" end)
    |> Enum.reduce("", &(&2 <> "#{&1}\n"))
  end

end
