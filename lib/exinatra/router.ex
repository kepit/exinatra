defmodule Exinatra.Router do

	defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      import Plug.Conn
      use Plug.Router
      @before_compile unquote(__MODULE__)

      plug Plug.Parsers, parsers: [:urlencoded, :multipart]

      plug :match
			plug :dispatch

			def dispatch(%Plug.Conn{assigns: assigns} = conn, _opts) do
				before_filter_fun()
				ret = Map.get(conn.private, :plug_route).(conn)
				after_filter_fun()
				ret
			end

			def start() do
				IO.puts "Running with Cowboy on http://localhost:4000"
				Plug.Adapters.Cowboy.http __MODULE__, []
			end

			before_filter do
			end
			
			after_filter do
			end
			
			defoverridable [before_filter_fun: 0, after_filter_fun: 0]
			
    end
  end

	defmacro __before_compile__(_) do
    quote do
      Plug.Router.match _ do
        conn = var!(conn)
				send_resp(conn, 404, "Not found")
      end
			
    end
  end

	defmacro before_filter(expression) do
		quote do
			def before_filter_fun() do
				unquote(expression)
			end
		end
	end
	
	defmacro after_filter(expression) do
		quote do
			def after_filter_fun() do
				unquote(expression)
			end
		end
	end

end
