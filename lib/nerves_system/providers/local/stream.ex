defmodule Nerves.System.Providers.Local.Stream do
  use GenServer

  @timer 10_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    file = opts[:file]
    if file != nil do
      File.write(file, "", [:write])
    end
    {:ok, %{
      file: opts[:file],
      timer: Process.send_after(self, :keep_alive, @timer),
      line: true
    }}
  end

  def handle_info({:io_request, from, reply_as, {:put_chars, _encoding, chars}} = data, s) do
    if s.file != nil do
      File.write(s.file, chars, [:append])
    end
    reply(from, reply_as, :ok)
    {:noreply, stdout(chars, data, s)}
  end

  def handle_info(:keep_alive, s) do
    IO.write "."
    s = reset_timer(s)
    {:noreply, %{s | line: true}}
  end

  def stdout(<<"\e[7m>>>", tail :: binary>> = chars, message, s) do
    s =
    if s.line == true do
      IO.write "\n"
      %{s | line: false}
    else
      s
    end

    [tail | _] =
      tail
      |> String.split("\e[7m")

    "\e[7m" <> tail
    |> String.strip
    |> IO.puts
    reset_timer(s)
  end
  def stdout(_, _, s), do: s



  defp reset_timer(s) do
    Process.cancel_timer(s.timer)
    %{s | timer: Process.send_after(self, :keep_alive, @timer)}
  end

  def reply(from, reply_as, reply) do
    send from, {:io_reply, reply_as, reply}
  end
end
