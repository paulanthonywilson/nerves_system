defmodule Nerves.System.Providers.Local do
  use Nerves.System.Provider
  alias Nerves.Env

  @dl_cache "~/.nerves/cache/buildroot"

  require Logger

  def cache_get(_system, _version, _dest) do
    {:error, :nocache}
  end

  def compile(system, dest) do
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
    build_platform = system.env[:build_platform] || :nerves_system_br

    copy_resources(system, dest)
    compile_defconfig(system, dest)
    compile_rootfs_additions(system, dest)

    bootstrap(build_platform, system, dest)
    build(build_platform, system, dest)
  end

  defp copy_resources(%Env.Dep{path: path}, dest) do
    Path.join(path, "src")
    |> File.cp_r!(Path.join(dest, "src"))
  end

  defp compile_defconfig(%Env.Dep{} = system, dest) do
    system_defconfig =
      Path.join(dest, system.env[:ext][:defconfig])

    unless File.exists?(system_defconfig), do: raise """
    System defconfig cannot be found at #{inspect system_defconfig}
    """

    # TODO: While compiling the defconfig, read lone by line and present k / v mis match errors
    Enum.each(Env.system_exts, fn(%{path: path, env: env}) ->
      if env[:ext] != nil do
        if env[:ext][:defconfig] != nil do
          ext_defconfig = Path.join(path, env[:ext][:defconfig])
          File.write!(system_defconfig, File.read!(ext_defconfig), [:append])
        end
      end
    end)
  end

  # TODO: Expand paths from metadata for extensions and append to the BR OVERLAY key in the defconfig.
  defp compile_rootfs_additions(%Env.Dep{} = system, dest) do

  end

  defp bootstrap(:nerves_system_br, %Env.Dep{} = system, dest) do
    cmd = Path.join(Env.dep(:nerves_system_br).path, "create-build.sh")
    shell! "#{cmd} #{Path.join(dest, system.env[:ext][:defconfig])} #{dest}"
  end

  defp build(:nerves_system_br, system, dest) do
    shell! "make", dir: dest
  end

  defp shell!(cmd, opts \\ []) do
    stream = IO.binstream(:standard_io, :line)
    %{status: 0} = Porcelain.shell(cmd, [in: stream, async_in: true, out: stream] ++ opts)
  end
end
