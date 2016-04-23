defmodule Nerves.System.Providers.Http do
  use Nerves.System.Provider

  @recv_timeout 120_000

  def cache_get(system, version, config, destination) do
    Application.ensure_all_started(:httpoison)
    shell_info "Downloading system from cache"
    config[:mirrors]
    |> get
    |> unpack(destination)
  end

  defp get([mirror | mirrors]) do
    HTTPoison.get(mirror, [], [follow_redirect: true, recv_timeout: @recv_timeout])
    |> result(mirrors)
  end

  defp result({:ok, %{status_code: status, body: body}}, _) when status in 200..299 do
    shell_info "System Downloaded"
    body
  end
  defp result(_, []) do
    raise "No mirror returned a result"
  end
  defp result(_, mirrors) do
    shell_info "switching mirror"
    get(mirrors)
  end

  defp unpack(tar, destination) do
    shell_info "Unpacking System"
    tmp_path = Path.join(destination, ".tmp")
    File.mkdir_p!(tmp_path)
    tar_file = Path.join(tmp_path, "system.tar.xz")
    File.write(tar_file, tar)

    System.cmd("tar", ["xf", "system.tar.xz"], cd: tmp_path)
    source =
      File.ls!(tmp_path)
      |> Enum.map(& Path.join(tmp_path, &1))
      |> Enum.find(&File.dir?/1)

    File.rm!(tar_file)
    File.cp_r(source, destination)
    File.rm_rf!(tmp_path)
    {:ok, destination}
  end

  defp shell_info(text) do
    Provider.shell_info "[http] #{text}"
  end
end
