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
				call_before_filters(conn)
				ret = Map.get(conn.private, :plug_route).(conn)
				call_after_filters(conn)
				ret
			end

			def start() do
				IO.puts "Running with Cowboy on http://localhost:4000"
				Plug.Adapters.Cowboy.http __MODULE__, []
			end

    end
  end

	defmacro __before_compile__(env) do
		module = env.module

    quote do
      Plug.Router.match _ do
        conn = var!(conn)
				send_resp(conn, 404, "Not found")
      end

			defp call_before_filters(%Plug.Conn{state: :unset} = conn) do
				try do
					before_filter_fun().(conn)
				end
			end

			defp call_after_filters(%Plug.Conn{state: :unset} = conn) do
				try do
					after_filter_fun().(conn)
				end
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
