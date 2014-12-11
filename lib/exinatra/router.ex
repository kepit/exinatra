defmodule Exinatra.Router do
  defmacro __using__(opts) do
    quote do

      import Exinatra.Router
      import Logger
      import Plug.Conn

#      @before_compile Exinatra.Router
      
      use Plug.Router
      use Exinatra.ResponseHelpers

      use PlugBasicAuth.Helpers

      plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], json_decoder: Json

      if unquote(opts[:auth]) == true do
  	    plug PlugBasicAuth, module: __MODULE__
      end

      if unquote(opts[:session]) == true do
        plug :put_secret_key_base
        plug Plug.Session, store: :cookie, key: unquote(opts[:session_key]), encryption_salt: unquote(opts[:session_encryption_salt]), signing_salt: unquote(opts[:session_signing_salt]), encrypt: false
      end

      def put_secret_key_base(conn, _) do
        put_in conn.secret_key_base, unquote(opts[:session_secret])
      end

      
      plug :match

      plug :fetch_params
      plug :fetch_cookies
      if unquote(opts[:session]) == true do
        plug :fetch_session
      end

      unless unquote(opts[:callbacks]) == false do
        plug :call_before_filters
      end

      plug :dispatch

      unless unquote(opts[:callbacks]) == false do
        plug :call_after_filters
      end
      
      defp call_before_filters(%Plug.Conn{state: :unset} = conn, opts) do
        if function_exported?(__MODULE__, :before_filter_fun,0) do
          conn = apply(__MODULE__, :before_filter_fun,[]).(conn)
        end
        conn
      end
      
      defp call_after_filters(%Plug.Conn{} = conn, opts) do
        if function_exported?(__MODULE__, :after_filter_fun,0) do
          conn = apply(__MODULE__, :after_filter_fun,[]).(conn)
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

# defmacro __before_compile__(_) do
#   quote do
#      import Exinatra.Router, only: []
#    end
# end

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
