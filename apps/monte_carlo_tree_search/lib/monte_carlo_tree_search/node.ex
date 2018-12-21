defmodule MonteCarloTreeSearch.Node do
  @moduledoc """
  A Monte Carlo Tree Search node.
  """

  alias MonteCarloTreeSearch.Payload

  @enforce_keys [:payload]
  defstruct(payload: %Payload{}, children: [])

  @spec leaf?(%__MODULE__{}) :: boolean()
  def leaf?(node = %__MODULE__{}), do: Enum.empty?(node.children)
end
