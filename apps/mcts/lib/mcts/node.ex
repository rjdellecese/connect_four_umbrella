defmodule MCTS.Node do
  @moduledoc """
  A Monte Carlo Tree Search node.
  """

  alias MCTS.Payload

  @enforce_keys [:payload]
  defstruct(payload: %Payload{}, children: [])

  @type t :: %__MODULE__{payload: Payload.t(), children: [__MODULE__.t()]}

  @spec leaf?(__MODULE__.t()) :: boolean()
  def leaf?(node = %__MODULE__{}), do: Enum.empty?(node.children)
end
