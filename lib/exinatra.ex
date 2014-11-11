defmodule Exinatra do
  defmacro __using__(opts) do
    quote do
      use Exinatra.Router, unquote(opts)
    end
  end
end
