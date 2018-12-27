defmodule MCTS.Payload do
  @moduledoc """
  Payload for a node in a Monte Carlo Tree Search tree.
  """

  defstruct(state: nil, reward: 0, visits: 0, fully_expanded: false)

  @type t :: %__MODULE__{
          state: any(),
          reward: non_neg_integer(),
          visits: non_neg_integer(),
          fully_expanded: boolean()
        }
end
