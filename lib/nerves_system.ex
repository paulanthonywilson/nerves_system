defmodule Nerves.System do

  def load_env(system_path, toolchain_path) do
    System.put_env("NERVES_TOOLCHAIN", toolchain_path)
    System.put_env("NERVES_SYSTEM", system_path)
  end
end
