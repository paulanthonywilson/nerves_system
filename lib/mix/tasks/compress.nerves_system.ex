defmodule Mix.Tasks.Compress.NervesSystem do
  use Mix.Task
  alias Nerves.Env
  alias Nerves.System.{Platform, Config}
  alias Nerves.System.Providers.Local.Stream, as: OutStream
  require Logger

  @moduledoc """
    Build a Nerves System
  """

  @dir "nerves/system"

  @shortdoc "Nerves Build System"

  def run(_args) do
    #if System.get_env("NERVES_SYSTEM_BUILT") != nil do
      Nerves.Env.initialize
      Application.put_env(:porcelain, :driver, Porcelain.Driver.Basic)
      Application.ensure_all_started(:porcelain)
      system     = Nerves.Env.system
      dest = Mix.Project.build_path
                   |> Path.join(@dir)
      shell! "make system", dir: dest
    #end
  end

  defp shell!(cmd, opts \\ []) do
    in_stream = IO.binstream(:standard_io, :line)
    {:ok, pid} = OutStream.start_link(file: Path.join(File.cwd!, "build.log"))
    out_stream = IO.stream(pid, :line)
    %{status: 0} = Porcelain.shell(cmd, [in: in_stream, async_in: true, out: out_stream, err: :out] ++ opts)
  end

end
