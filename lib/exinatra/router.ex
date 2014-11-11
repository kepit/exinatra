defmodule Exinatra.Router do
  defmacro __using__(opts) do
    quote location: :keep do

      import Exinatra.Router
      @before_compile Exinatra.Router

      use Plug.Builder

      import Plug.Conn
      import Logger
      use Exinatra.ResponseHelpers


      if unquote(opts[:code_reload]) == true do
        plug Exinatra.HotCodeReload
      end

      plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], json_decoder: JSEX

      if unquote(opts[:logger]) != false do
        plug Plug.Logger
      end
      
      use PlugBasicAuth.Helpers

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



      plug :fetch_params
      plug :fetch_cookies
      if unquote(opts[:session]) == true do
        plug :fetch_session
      end

      plug :match

      if unquote(opts[:callbacks]) == false do
        plug :dispatch
      else
        plug :dispatch_with_callbacks
      end

      def match(conn, _opts) do
        Plug.Conn.put_private(conn, :plug_route, do_match(conn.method, conn.path_info))
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
      import Exinatra.Router, only: []

      #Exinatra.Router.match _ do
      #  conn = var!(conn)
      #  send_resp(conn, 404, "Not found")
      #end

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

  

  ## Match

  @doc """
  Main API to define routes. It accepts an expression representing
  the path and many options allowing the match to be configured.
  ## Examples
      match "/foo/bar", via: :get do
        send_resp(conn, 200, "hello world")
      end
  ## Options
  `match` accepts the following options:
  * `:via` - matches the route against some specific HTTP methods
  * `:do` - contains the implementation to be invoked in case
    the route matches
  """
  defmacro match(expression, options, opts \\ [], contents \\ []) do
    compile(:build_match, expression, Keyword.merge(contents, options), opts, __CALLER__)
  end

  @doc """
  Dispatches to the path only if it is get request.
  See `match/3` for more examples.
  """
  defmacro get(path, opts \\ [], contents) do
    compile(:build_match, path, Keyword.put(contents, :via, :get), opts, __CALLER__)
  end

  @doc """
  Dispatches to the path only if it is post request.
  See `match/3` for more examples.
  """
  defmacro post(path, opts \\ [], contents) do
    compile(:build_match, path, Keyword.put(contents, :via, :post), opts, __CALLER__)
  end

  @doc """
  Dispatches to the path only if it is put request.
  See `match/3` for more examples.
  """
  defmacro put(path, opts \\ [], contents) do
    compile(:build_match, path, Keyword.put(contents, :via, :put), opts, __CALLER__)
  end

  @doc """
  Dispatches to the path only if it is patch request.
  See `match/3` for more examples.
  """
  defmacro patch(path, opts \\ [], contents) do
    compile(:build_match, path, Keyword.put(contents, :via, :patch), opts, __CALLER__)
  end

  @doc """
  Dispatches to the path only if it is delete request.
  See `match/3` for more examples.
  """
  defmacro delete(path, opts \\ [], contents) do
    compile(:build_match, path, Keyword.put(contents, :via, :delete), opts, __CALLER__)
  end

  @doc """
  Dispatches to the path only if it is options request.
  See `match/3` for more examples.
  """
  defmacro options(path, opts \\ [], contents) do
    compile(:build_match, path, Keyword.put(contents, :via, :options), opts, __CALLER__)
  end

  @doc """
  Forwards requests to another Plug. The path_info of the forwarded
  connection will exclude the portion of the path specified in the
  call to `forward`.
  ## Examples
      forward "/users", to: UserRouter
  ## Options
  `forward` accepts the following options:
  * `:to` - a Plug where the requests will be forwarded
  All remaining options are passed to the underlying plug.
  """
  defmacro forward(path, options) when is_binary(path) do
    quote do
      {target, options} = Keyword.pop(unquote(options), :to)
      if is_nil(target) or !is_atom(target) do
        raise ArgumentError, message: "expected :to to be an alias or an atom"
      end

      @plug_forward_target target
      @plug_forward_opts   target.init(options)

      match unquote(path <> "/*glob") do
        Plug.Router.Utils.forward(var!(conn), var!(glob), @plug_forward_target, @plug_forward_opts)
      end
    end
  end

  ## Match Helpers

  # Entry point for both forward and match that is actually
  # responsible to compile the route.
  defp compile(builder, expr, options, opts, caller) do
    methods = options[:via]
    body    = options[:do]

    unless body do
      raise ArgumentError, message: "expected :do to be given as option"
    end

    {method, guard} = convert_methods(List.wrap(methods))
    {path, guards}  = extract_path_and_guards(expr, guard)
    {_vars, match}  = apply Plug.Router.Utils, builder, [Macro.expand(path, caller)]

    unless is_nil(opts[:content_type]) do
      set_content_type = quote do 
        var!(conn) = Plug.Conn.put_resp_content_type(var!(conn), unquote(opts[:content_type]))
      end
    else
      set_content_type = quote do
      end
    end

    quote do
      defp do_match(unquote(method), unquote(match)) when unquote(guards) do
        fn var!(conn) ->
          unquote(set_content_type)
          unquote(body)
        end
      end
    end
  end

  # Convert the verbs given with :via into a variable
  # and guard set that can be added to the dispatch clause.
  defp convert_methods([]) do
    {quote(do: _), true}
  end

  defp convert_methods([method]) do
    {Plug.Router.Utils.normalize_method(method), true}
  end

  defp convert_methods(methods) do
    methods = Enum.map methods, &Plug.Router.Utils.normalize_method(&1)
    var = quote do: method
    {var, quote(do: unquote(var) in unquote(methods))}
  end

  # Extract the path and guards from the path.
  defp extract_path_and_guards({:when, _, [path, guards]}, true) do
    {path, guards}
  end

  defp extract_path_and_guards({:when, _, [path, guards]}, extra_guard) do
    {path, {:and, [], [guards, extra_guard]}}
  end

  defp extract_path_and_guards(path, extra_guard) do
    {path, extra_guard}
  end


end
