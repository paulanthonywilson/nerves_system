defmodule Nerves.System.Config do

  @t_merge [:"BR2_ROOTFS_OVERLAY"]

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
      |> Keyword.new(& list_to_keyword/1)
    Agent.update(__MODULE__, &(merge(config, &1)))
  end

  def dump do
    Agent.get(__MODULE__, &(&1))
    |> Enum.map(fn ({k, v}) -> "#{k}=#{v}" end)
    |> Enum.reduce("", &(&2 <> "#{&1}\n"))
  end

  def merge({k, v}, list) when k in @t_merge do
    case Keyword.get(list, k) do
      nil -> Keyword.put(list, k, v)
      v2 -> Keyword.put(list, k, Enum.join([v, v2], " "))
    end
  end

  def merge({k, v}, list), do: Keyword.put_new(list, k, v)

  def merge(l1, l2) when is_list(l1) and is_list(l2) do
    Enum.reduce(l1, l2, fn(line, l2) -> merge(line, l2) end)
  end

  def list_to_keyword([k, v]), do: {String.to_atom(k), v}

end
