defmodule Mix.Tasks.Compile.NervesSystem do
  use Mix.Task
  alias Nerves.Env

  require Logger

  @moduledoc """
    Build a Nerves System
  """

  @shortdoc "Nerves Build System"


  def run(_args) do
    Mix.shell.info "[nerves_system][compile]"
    {:ok, _} = Application.ensure_all_started(:nerves_system)

    config    = Mix.Project.config
    app_path  = Mix.Project.app_path(config)

    app = config[:app]
    version = config[:version]

    Path.join(app_path, "/ebin")
    |> Code.prepend_path

    clean(Path.join(app_path, "nerves_system"))

    {:ok, _} = Application.ensure_all_started(app)
    system_config = Application.get_all_env(app)

    provider = system_config[:provider]
    cache_provider = provider[:cache] || default_provider(:cache)
    compiler_provider = provider[:compiler] || default_provider(:compiler)
    cache_provider = Module.concat(Nerves.System.Providers, String.capitalize(cache_provider))
    compiler_provider = Module.concat(Nerves.System.Providers, String.capitalize(compiler_provider))
    # determine if we can cache anyways
    #  1. do we have any system extensions?
    system_exts = Env.system_exts
    if system_exts != [] do
      system_exts = Enum.map(system_exts, &(Map.get(&1, :app)))
      Logger.debug "Exts: #{inspect system_exts}"
      Mix.shell.info """
      System Extensions Present: #{Enum.join(system_exts, ~s/ /)}
      Skipping cache provider
      """
      compiler_provider.compile(app, Path.join(app_path, "nerves_system"))
    else
      cache_provider.cache_get(app, version, Path.join(app_path, "nerves_system"))
      |> cache_response(compiler_provider)
    end
  end

  # TODO: Change the default providers to be set according to host_platform
  defp default_provider(:cache) do
    System.get_env("NERVES_SYSTEM_CACHE_PROVIDER") || "bakeware"
  end

  defp default_provider(:compiler) do
    System.get_env("NERVES_SYSTEM_COMPILER_PROVIDER") || "bakeware"
  end

  defp clean(dest) do
    File.rm_rf(dest)
  end

  # defp stale?(app_path) do
  #   app_path = app_path
  #   |> Path.join("nerves_system")
  #   if (File.dir?(app_path)) do
  #     src =  Path.join(File.cwd!, "src")
  #     sources = src
  #     |> File.ls!
  #     |> Enum.map(& Path.join(src, &1))
  #
  #     Mix.Utils.stale?(sources, [app_path])
  #   else
  #     true
  #   end
  # end


  defp cache_response({:ok, system_path}, compiler_provider) do
    Mix.shell.info "System downloaded form cache provider"
    #deploy_build(system)
    {:ok, system_path}
  end

  defp cache_response({:error, :nocache}, compiler_provider) do
    # try to compile
  end
  defp cache_response({:error, reason}, compiler_provider) do
    Mix.shell.info """
    System download from cache provider failed for reason:
    #{inspect reason}
    """
  end

  # def deploy_build(system_tar) do
  #   config      = Mix.Project.config
  #   app_path    = Mix.Project.app_path(config)
  #
  #   tar_file = app_path <> "/system.tar.xz"
  #   write_result = File.write(tar_file, system_tar)
  #   System.cmd("tar", ["xf", tar_file], cd: app_path)
  #   File.rm!(tar_file)
  #   target = Path.join(app_path, "nerves_system")
  #   File.touch(target)
  #   {:ok, target}
  # end



end
