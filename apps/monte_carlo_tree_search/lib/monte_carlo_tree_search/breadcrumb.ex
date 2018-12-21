defmodule MonteCarloTreeSearch.Breadcrumb do
  @moduledoc """
  A breadcrumb for tracking the current location of the zipper.
  """

  defstruct(
    payload: nil,
    left_nodes: [],
    right_nodes: []
  )
end
