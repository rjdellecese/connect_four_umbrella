defmodule MonteCarloTreeSearch.NodeTest do
  use ExUnit.Case, async: true
  doctest MonteCarloTreeSearch.Node

  alias MonteCarloTreeSearch.Node

  setup do
    leaf_node = %Node{payload: "leaf", children: []}
    not_leaf_node = %Node{payload: "not_leaf", children: [leaf_node]}
    %{leaf_node: leaf_node, not_leaf_node: not_leaf_node}
  end

  describe "leaf?/1" do
    test "returns true if node is a leaf node", %{leaf_node: leaf_node} do
      assert Node.leaf?(leaf_node) == true
    end

    test "returns false if node is not a leaf node", %{not_leaf_node: not_leaf_node} do
      assert Node.leaf?(not_leaf_node) == false
    end
  end
end
