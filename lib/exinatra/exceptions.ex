defmodule Exinatra.Exceptions do
  @moduledoc """
  Catches runtime exceptions for displaying an error screen instead of an empty
  response in dev environments.
  """
  import Logger

  def handle(conn, kind, e) do
        message = log_request(conn) <> log_cause(kind, e) <> log_stacktrace(System.stacktrace)
	message = String.to_char_list(message)
        Logger.error(message)
        conn
   end


   def handle_html(conn, kind, e) do
        env = System.get_env
        assigns = [
          kind: get_kind(e, kind),
          value: e,
          elixir_build_info: System.build_info,
          env: Map.keys(env) |> Enum.map(fn(key) ->
            [ key: key,
              value: Map.get(env, key) ]
          end),
          stacktrace: System.stacktrace |> Enum.map(fn({mod, fun, arr, meta}) ->
            [ module: String.Chars.to_string(mod) |> String.replace("Elixir.", ""),
              function: String.Chars.to_string(fun),
              arrity: arr,
              file: meta[:file],
              line: meta[:line],
              source: get_file_contents(meta[:file]) ]
          end),
          conn: conn
        ]
        eex_opts = [file: __ENV__.file, line: __ENV__.line, engine: EEx.SmartEngine]
	%{ conn | state: :set}
          |> Plug.conn.put_resp_header("content-type", "text/html; charset=utf-8")
          |> Plug.conn.send_resp(500, Exinatra.View.Exceptions |> EEx.eval_string([assigns: assigns], eex_opts))
  end

  defp get_kind(e, kind) when is_atom(e) do
    kind
  end
  # defp get_kind(e, _kind) when is_struct(e) do
  #   atom_to_binary(e.__record__(:name))
  #     |> String.replace("Elixir.", "")
  # end

  defp get_kind(_e, kind) do
    kind
  end

  defp get_file_contents(nil), do: "no source available"
  defp get_file_contents(file) do
    if File.exists?(file) do
      File.read!(file)
    else
      case Path.wildcard("deps/*/#{file}") do
        [] -> "no source available for '#{file}'"
        matches ->
          matches |> hd |> File.read!
      end
    end
  end

  defp log_request(conn) do
    "#{conn.method} /#{conn.path_info |> Enum.join("/")}\n"
  end



#  defp log_cause(:error, value) when is_atom(value) do
#    "  Cause: (Error) #{inspect value}\n"
#  end
#  defp log_cause(:error, value) when is_record(value) do
#     "  Cause: (#{inspect value.__record__(:name)}) #{value.message}\n"
#   end
#  defp log_cause(:error, value) do
#    "  Cause: (#{inspect value}) #{value.message}\n"
#  end

  defp log_cause(kind, value) do
    "  Cause: (#{kind}) #{inspect(value)}\n"
  end

  defp log_stacktrace(stacktrace) do
    Enum.reduce stacktrace, "  Stacktrace:\n", fn(trace, acc) ->
      acc <> "    " <> Exception.format_stacktrace_entry(trace) <> "\n"
    end
  end
end
