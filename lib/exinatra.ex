defmodule Exinatra do
	defmacro __using__(_) do
		quote do
			use Exinatra.Router
		end
	end

end
