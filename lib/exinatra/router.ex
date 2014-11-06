defmodule Exinatra.Router do
  defmacro __using__(opts) do
    quote do

      import unquote(__MODULE__)
      import Plug.Conn
      import Logger

      use Plug.Router
      use Exinatra.ResponseHelpers

      @before_compile unquote(__MODULE__)

      if unquote(opts[:code_reload]) == true do
        plug Exinatra.HotCodeReload
      end

      plug Plug.Parsers, parsers: [:urlencoded, :multipart]

      if unquote(opts[:logger]) != false do
        plug Plug.Logger
      end
      
      use PlugBasicAuth.Helpers

      if unquote(opts[:auth]) == true do
  	    plug PlugBasicAuth, module: __MODULE__
      end

      plug :match

      if unquote(opts[:callbacks]) == false do
        plug :dispatch
      else
        plug :dispatch_with_callbacks
      end


      def match(conn, _opts) do
        Plug.Conn.put_private(conn,
                              :plug_route,
                              do_match(conn.method, conn.path_info))
      end

      
      def dispatch(%Plug.Conn{assigns: assigns} = conn, _opts) do
        Map.get(conn.private, :plug_route).(conn)
      end

      def dispatch_with_callbacks(%Plug.Conn{assigns: assigns} = conn, _opts) do
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
        Logger.info "Running #{__MODULE__} on port: #{port}"
        Plug.Adapters.Cowboy.http __MODULE__, [], [{:port, port}]
      end

      def start_link(args) do
        Logger.info "Running #{__MODULE__} on port: #{args[:port]}"
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
          conn = apply(__MODULE__, :before_filter_fun,[]).(conn)
        end
        conn
      end

      defp call_after_filters(%Plug.Conn{} = conn) do
        if function_exported?(__MODULE__, :after_filter_fun,0) do
          conn = apply(__MODULE__, :after_filter_fun,[]).(conn)
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
