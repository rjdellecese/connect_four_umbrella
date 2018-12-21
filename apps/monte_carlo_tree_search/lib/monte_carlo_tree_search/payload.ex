defmodule MonteCarloTreeSearch.Payload do
  @moduledoc """
  Payload for a node in a Monte Carlo Tree.
  """

  # Reward is the number of wins of simulations that have passed through the given node.
  defstruct(state: nil, reward: 0, visits: 0, fully_expanded: false)

  # TODO: Make fully_expanded a function?
end
