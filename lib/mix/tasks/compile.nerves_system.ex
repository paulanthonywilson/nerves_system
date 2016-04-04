defmodule Mix.Tasks.Compile.NervesSystem do
  use Mix.Task
  alias Nerves.Env

  require Logger

  @moduledoc """
    Build a Nerves System
  """

  @shortdoc "Nerves Build System"


  def run(_args) do
    Env.initialize
    if Env.stale? do
      Mix.shell.info "[nerves_system][compile]"
      config    = Mix.Project.config
      app_path  = Mix.Project.app_path(config)

      app = config[:app]
      version = config[:version]

      clean(Path.join(app_path, "nerves_system"))

      system_config = Env.system.config
      provider = system_config[:provider]
      cache_provider = provider[:cache] || default_provider(:cache)

      cache_provider = Module.concat(Nerves.System.Providers, String.capitalize(cache_provider))

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
        compile(app, app_path, system_config)
      else
        cache_resp = cache_provider.cache_get(app, version, system_config, Path.join(app_path, "nerves_system"))
        case cache_resp do
          {:ok, _} -> :ok
          {:error, :nocache} -> compile(app, app_path, system_config)
          {:error, error} -> cache_error(error)
        end
      end
      manifest =
        Env.deps
        |> :erlang.term_to_binary
      path = Path.join(app_path, ".nerves.lock")
      result = File.write(path, manifest)
    end
  end

  defp compile(app, path, config) do
    Logger.debug "Compile System"
    provider = providers(config)[:compiler] || default_provider(:compiler)
    compiler_provider = Module.concat(Nerves.System.Providers, String.capitalize(provider))
    compiler_provider.compile(app, config, Path.join(path, "nerves_system"))
    |> compile_result(provider)
  end

  defp compile_result({:error, error}, provider) do
    provider =
      provider
      |> to_string
    raise Nerves.System.Exception, message: """
    The #{provider} compiler provider was unable to compile the nerves system
    #{error}
    """
  end

  defp compile_result(_, _), do: :ok

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

  defp providers(system_config) do
    system_config[:provider] || []
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

  defp cache_error(reason) do
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
