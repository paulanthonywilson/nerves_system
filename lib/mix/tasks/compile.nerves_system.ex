defmodule Mix.Tasks.Compile.NervesSystem do
  use Mix.Task
  alias Nerves.Env
  require Logger

  @moduledoc """
    Build a Nerves System
  """

  @dir "nerves/system"

  @shortdoc "Nerves Build System"

  def run(_args) do
    if System.get_env("NERVES_SYSTEM_BUILT") == nil do
      preflight
    end
  end

  defp preflight do
    Env.initialize
    case System.get_env("NERVES_SYSTEM") do
      nil ->
        if Env.stale? do
          build
        end
      system_path ->
        platform = Env.system_platform
        platform.config(Env.system, system_path)
    end
    System.put_env("NERVES_SYSTEM_BUILT", "1")
  end

  defp build do
    Mix.shell.info "[nerves_system][compile]"
    config      = Mix.Project.config
    build_path  = Mix.Project.build_path
                  |> Path.join(@dir)

    app = config[:app]
    version = config[:version]

    clean(build_path)

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
      compile(app, build_path, system_config)
    else
      cache_resp = cache_provider.cache_get(app, version, system_config, build_path)
      case cache_resp do
        {:ok, _} -> :ok
        {:error, :nocache} -> compile(app, build_path, system_config)
        {:error, error} -> cache_error(error)
      end
    end
    manifest =
      Env.deps
      |> :erlang.term_to_binary
    path = Path.join(build_path, ".nerves.lock")
    File.write(path, manifest)
  end

  defp compile(app, build_path, config) do
    Logger.debug "Compile System"
    platform = Env.system_platform
    platform.config(Env.system, build_path)

    provider = providers(config)[:compiler] || default_provider(:compiler)
    compiler_provider = Module.concat(Nerves.System.Providers, String.capitalize(provider))
    compiler_provider.compile(app, config, build_path)
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
    System.get_env("NERVES_SYSTEM_CACHE") || "http"
  end

  defp default_provider(:compiler) do
    System.get_env("NERVES_SYSTEM_COMPILER") || "vagrant"
  end

  defp clean(dest) do
    File.rm_rf(dest)
  end

  defp providers(system_config) do
    system_config[:provider] || []
  end

  defp cache_error(reason) do
    Mix.shell.info """
    System download from cache provider failed for reason:
    #{inspect reason}
    """
  end

end
