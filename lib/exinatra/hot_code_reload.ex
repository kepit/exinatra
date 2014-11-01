defmodule Exinatra.HotCodeReload do
  import Plug.Conn

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _) do
    reload(Mix.env)
    conn
  end

  defp reload(:dev) do
    Mix.Tasks.Compile.Elixir.run([])
  end
  defp reload(_), do: :noreload
end
