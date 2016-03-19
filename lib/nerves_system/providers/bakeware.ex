defmodule Nerves.System.Providers.Bakeware do
  use Nerves.System.Provider

  require Logger

  def cache_get(system, version, destination) do
    Application.put_env(:porcelain, :driver, Porcelain.Driver.Basic)
    Application.ensure_all_started(:bake)
    system_config = Application.get_all_env(system)
    bakeware_config = system_config[:bakeware]
    cache_resp =
      bakeware_config[:recipe]
      |> cache_recipe_get(version)
      |> copy_build(system, version, destination)
  end

  def compile(system) do

  end

  defp cache_recipe_get(nil, _) do
    shell_info ~s/bakeware: [recipe: ""] is not configured/
  end
  defp cache_recipe_get(recipe, version) do
    shell_info "cache get: #{recipe} #{version}"
    Bake.Api.System.get(%{recipe: recipe, version: version})
    |> cache_recipe_receive
  end

  # received response
  defp cache_recipe_receive({:ok, %{status_code: status} = resp}) when status in 200..299 do
    %{data: %{host: host, path: path}} = Poison.decode!(resp.body, keys: :atoms)
    get_asset("#{host}/#{path}")
  end

  defp cache_recipe_receive({:error, reason}) do
    {:error, :nocache}
  end

  defp get_asset(url) do
    shell_info "downloading system image"
    case Bake.Api.request(:get, url, []) do
      {:ok, %{status_code: code, body: tar}} when code in 200..299 ->
        {:ok, tar}
      {:error, response} -> {:error, "Failed to download system from cache"}
    end
  end

  defp copy_build({:ok, tar}, system, version, destination),
    do: copy_build(tar, system, version, destination)
  defp copy_build({:error, error}, _, _, _),
    do: {:error, error}
  defp copy_build(system_tar, system, version, destination) do
    tmp_dir = Path.join(File.cwd!, ".bakeware-tmp")
    File.mkdir_p! tmp_dir
    tar_file = tmp_dir <> "/system.tar.xz"
    File.write(tar_file, system_tar)
    System.cmd("tar", ["xf", "system.tar.xz"], cd: tmp_dir)
    File.rm!(tar_file)
    system_config = Application.get_all_env(system)
    bakeware_config = system_config[:bakeware]
    recipe = bakeware_config[:recipe]
    target = bakeware_config[:target]
    Logger.debug "Bakeware recipe: #{inspect bakeware_config}"
    recipe = String.split("/", recipe)
    |> List.last

    File.cp_r(Path.join(tmp_dir, "#{target}-#{version}"), destination)
    File.rm_rf!(tmp_dir)
    {:ok, destination}
  end

  defp shell_info(text) do
    Provider.shell_info "[bakeware] #{text}"
  end
end
