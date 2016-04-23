defmodule Nerves.System.Config do
  # https://git.busybox.net/buildroot/tree/support/kconfig/merge_config.sh
  @t_merge [:"BR2_ROOTFS_OVERLAY"]

  def start do
    Agent.start_link fn -> [comments: []] end, name: __MODULE__
  end

  # TODO: Add an api call for stopping the agent

  def load(config_file) do
    config =
      config_file
      |> File.open!
      |> IO.stream(:line)
      |> Stream.map(& String.strip/1)
    {comments, values} =
      config
      |> Enum.partition(& String.starts_with?(&1, "#"))
    config =
      values
      |> Enum.map(& String.split(&1, "="))
      |> Keyword.new(& list_to_keyword/1)
      |> Keyword.put(:comments, comments)
    Agent.update(__MODULE__, &(merge(config, &1)))
  end

  def dump do
    Agent.get(__MODULE__, &(&1))
    |> Enum.map(fn
      {:comments, c} -> Enum.join(c, "\n")
      {k, v} = t -> "#{k}=#{v}"

    end)
    |> Enum.reduce("", &(&2 <> "#{&1}\n"))
  end

  def merge({:comments, v}, list) do
    Keyword.put(list, :comments, list[:comments] ++ v)
  end
  def merge({k, v}, list) when k in @t_merge do
    case Keyword.get(list, k) do
      nil -> Keyword.put(list, k, v)
      v2 -> Keyword.put(list, k, Enum.join([v, v2], " "))
    end
  end

  def merge({k, v}, list) do
    case Keyword.get(list, k) do
      nil -> Keyword.put(list, k, v)
      orig -> raise Nerves.System.Exception, message: """
        Attempt to redefine key #{k} in defconfig
        Original Value: #{orig}
        Redefinition: #{v}
      """
    end

  end

  def merge(l1, l2) when is_list(l1) and is_list(l2) do
    Enum.reduce(l1, l2, fn(line, l2) -> merge(line, l2) end)
  end

  def list_to_keyword([k, v]), do: {String.to_atom(k), v}

end
