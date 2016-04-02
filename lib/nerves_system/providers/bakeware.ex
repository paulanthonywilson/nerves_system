defmodule Nerves.System.Providers.Bakeware do
  use Nerves.System.Provider

  require Logger

  def cache_get(system, version, config, destination) do
    Application.put_env(:porcelain, :driver, Porcelain.Driver.Basic)
    Application.ensure_all_started(:bake)
    bakeware_config = config[:bakeware]
    cache_resp =
      bakeware_config[:recipe]
      |> cache_recipe_get(version)
      |> copy_build(system, version, config, destination)
  end


  @doc """
  Notes about the bakeware compiler.
  Inorder for us to be able to compile remotely, we need to package all
  the assets and send them to bakeware.
  The packaged nerves_env will contain a manifest describing the job to be compiled

    action: :compile
    type: :system
    platform: :nerves

  This will call an endpoint on bakeware at
  bakeware.io/api/compiler
  and pass the required payload. this endpoint will require a bakeware user.

  The compiler will respond with

  200 ok
   task:
     id: 12345
     position: 1
     action: :compile
     type: :system
     platform: :nerves

  Upon receipt, bake establishes a connection to bakeware on the users channel
  for example, if you are signed into bakeware as skroob, you would join the channel
  users:skroob and listen for messages for the event task:12345.

  Once the task is picked up by an oven, the oven will attempt to handshake with
  the remote terminal by broadcasting a handshake message and awaiting response.
  The oven will attempt this 5 times at 5 second intervals before considering the remote
  terminal to be unresponsive and canceling the task.

  The oven proceeds by unpacking the env files in a staging directory and initializing
  nerves_env by loading the manifest. Once loaded, the oven will perform the action
  on the package from within the path of the dep identifying itself by the type being passed

  For Example:
  Nerves.Env.deps [
    %{app: :nerves_system_bbb,  type: :system,            path: "/some_path/nerves_system_bbb"},
    %{app: :nerves_system,      type: :system_compiler,   path: "/some_path/nerves_system"},
    %{app: :nerves_system_br,   type: :system_platform,   path: "/some_path/nerves_system_br"},
  ]

  In this example, the oven would issue the command `mix compile` from within the directory
  /some_path/nerves_system_bbb
  """
  def compile(_system, _config, _dest) do
    # Serialize the env
    {:ok, tar} = Nerves.Env.serialize
    resp = File.read!(tar)
    |> Bake.Api.Compile.post
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

  defp copy_build({:ok, tar}, system, version, config, destination),
    do: copy_build(tar, system, version, config, destination)
  defp copy_build({:error, error}, _, _, _, _),
    do: {:error, error}
  defp copy_build(system_tar, system, version, config, destination) do
    tmp_dir = Path.join(File.cwd!, ".bakeware-tmp")
    File.mkdir_p! tmp_dir
    tar_file = tmp_dir <> "/system.tar.xz"
    File.write(tar_file, system_tar)
    System.cmd("tar", ["xf", "system.tar.xz"], cd: tmp_dir)
    File.rm!(tar_file)

    bakeware_config = config[:bakeware]
    recipe = bakeware_config[:recipe]
    target = bakeware_config[:target]

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
