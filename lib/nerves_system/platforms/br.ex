defmodule Nerves.System.Platforms.BR do
  use Nerves.System.Platform
  alias Nerves.Env
  alias Nerves.System.Config

  require Logger

  @dest "config"

  def config(%Env.Dep{} = system, dest) do
    build_config = Platform.build_config(system)
    dest = Path.join(dest, build_config[:dest])
    File.mkdir_p!(dest)
    copy_configs(system, build_config, dest)
    assemble_defconfig(system, build_config, dest)
  end

  def bootstrap do
    Env.deps_by_type(:system_platform)
    |> List.first
    |> Map.get(:path)
    |> Path.join("nerves_env.exs")
    |> Code.require_file
  end

  def default_build_config do
    [defconfig: "nerves_defconfig",
     kconfig: "Config.in",
     dest: @dest,
     assets: []]
  end

  defp copy_configs(%Env.Dep{} = system, build_config, dest) do
    Path.join(system.path, build_config[:defconfig])
    |> File.cp(Path.join(dest, build_config[:defconfig]))

    (build_config[:package_files] || [])
    |> Enum.each(fn (file) ->
      Path.join(system.path, file)
      |> File.cp(Path.join(dest, file))
    end)

    kconfig_path = Path.join(system.path, build_config[:kconfig])
    if File.exists?(kconfig_path) do
      File.cp(kconfig_path, dest)
    else
      Path.join(dest, "Config.in")
      |> File.touch
    end
  end

  defp assemble_defconfig(system, build_config, dest) do
    system_defconfig =
      dest
      |> Path.join(build_config[:defconfig])

    unless File.exists?(system_defconfig), do: raise """
    System defconfig cannot be found at #{inspect system_defconfig}
    """
    Config.start
    Config.load(system_defconfig)

    Enum.each(Env.system_exts, fn(%{path: path, config: config}) ->
      if config[:build_config] != nil do
        if config[:build_config][:defconfig] != nil do
          ext_defconfig = Path.join(path, config[:build_config][:defconfig])
          Config.load(ext_defconfig)
        end
      end
    end)
    File.write!(system_defconfig, Config.dump)
  end
end
