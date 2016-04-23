defmodule Nerves.System.Providers.Local do
  use Nerves.System.Provider
  alias Nerves.Env
  alias Nerves.System.{Config, Platform}

  @dl_cache "~/.nerves/cache/buildroot"

  require Logger

  def cache_get(_system, _version, _config, _dest) do
    {:error, :nocache}
  end

  def compile(system, config, dest) do
    {_, type} = :os.type
    compile(type, system, config, dest)
  end

  def compile(:linux, _system, config, dest) do
    # TODO: Perform a platform check
    Logger.debug "Local Compiler"
    Application.put_env(:porcelain, :driver, Porcelain.Driver.Basic)
    Application.ensure_all_started(:porcelain)
    # Find the build platform dep
    # Call out to the command to create a build
    #  #{build_platform}/create_build.sh #{config_dir} #{destination}
    File.mkdir_p!(dest)
    File.mkdir_p(Path.expand(@dl_cache))

    system = Env.system
    build_platform = system.config[:build_platform] || Nerves.System.BR

    bootstrap(build_platform, system, dest)
    build(build_platform, system, dest)
  end

  def compile(type, _, _) do
    {:error, """
    Local compiler support is not available for your host: #{type}
    You can compile systems using a different provider like bakeware

    You can configure your host to use a different compiler provider by setting the variable
    NERVES_SYSTEM_COMPILER_PROVIDER=bakeware
    """}
  end

  defp copy_resources(%Env.Dep{path: source}, dest) do
    File.cp_r!(source, dest)
  end

  defp compile_defconfig(%Env.Dep{} = system, dest) do
    system_defconfig =
      Path.join(dest, system.config[:build_config][:defconfig])

    unless File.exists?(system_defconfig), do: raise """
    System defconfig cannot be found at #{inspect system_defconfig}
    """
    Config.start
    Config.load(system_defconfig)


    # TODO: While compiling the defconfig, read line by line and present k / v mis match errors
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



  # TODO: Expand paths from metadata for extensions and append to the BR OVERLAY key in the defconfig.
  defp compile_rootfs_additions(%Env.Dep{} = _system, _dest) do
    #Enum.each(Env.system_exts, fn(%{path: path, config: config}) ->
  end

  defp bootstrap(Nerves.System.Platforms.BR, %Env.Dep{} = system, dest) do
    cmd = Path.join(Env.dep(:nerves_system_br).path, "create-build.sh")
    build_config = Platform.build_config(system)
    config_dir = Path.join(dest, build_config[:dest])
    shell! "#{cmd} #{Path.join(config_dir, build_config[:defconfig])} #{dest}"
  end

  defp build(Nerves.System.Platforms.BR, _system, dest) do
    shell! "make", dir: dest
  end

  defp shell!(cmd, opts \\ []) do
    stream = IO.binstream(:standard_io, :line)
    %{status: 0} = Porcelain.shell(cmd, [in: stream, async_in: true, out: stream] ++ opts)
  end
end
