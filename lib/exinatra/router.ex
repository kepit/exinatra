defmodule Exinatra.Router do
  defmacro __using__(_) do
    quote do

      import unquote(__MODULE__)
      import Plug.Conn
      use Plug.Router
      use Exinatra.ResponseHelpers
      @before_compile unquote(__MODULE__)

      plug Plug.Parsers, parsers: [:urlencoded, :multipart]
      plug Plug.Logger

      plug :match
      plug :dispatch

      def dispatch(%Plug.Conn{assigns: assigns} = conn, _opts) do

        try do
          conn = call_before_filters(conn)
          conn = Map.get(conn.private, :plug_route).(conn)
          conn = call_after_filters(conn)
        catch
          kind,e ->
            conn = Exinatra.Exceptions.handle(conn, kind, e)
        end
        conn
      end

      def start(port) do
        IO.puts "Running #{__MODULE__} on port: #{port}"
        Plug.Adapters.Cowboy.http __MODULE__, [], [{:port, port}]
      end

      def start_link(args) do
        IO.puts "Running #{__MODULE__} on port: #{args[:port]}"
	Plug.Adapters.Cowboy.http __MODULE__, [], args
      end
    end
  end

  defmacro __before_compile__(_) do

    quote do
      Plug.Router.match _ do
        conn = var!(conn)
        send_resp(conn, 404, "Not found")
      end

      defp call_before_filters(%Plug.Conn{state: :unset} = conn) do
        if function_exported?(__MODULE__, :before_filter_fun,0) do
          conn = before_filter_fun().(conn)
        end
        conn
      end

      defp call_after_filters(%Plug.Conn{} = conn) do
        if function_exported?(__MODULE__, :after_filter_fun,0) do
          conn = after_filter_fun().(conn)
        end
        conn
      end

    end
  end

  defmacro before_filter(expression) do
    quote do
      def before_filter_fun() do
        fn var!(conn) -> unquote(expression[:do]) end
      end
    end
  end
	
  defmacro after_filter(expression) do
    quote do
      def after_filter_fun() do
        fn var!(conn) -> unquote(expression[:do]) end
      end
    end
  end

end
