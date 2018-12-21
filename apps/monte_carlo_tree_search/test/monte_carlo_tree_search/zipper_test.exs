defmodule MonteCarloTreeSearch.ZipperTest do
  use ExUnit.Case, async: true
  doctest MonteCarloTreeSearch.Zipper

  alias MonteCarloTreeSearch.{Node, Zipper}

  setup do
    ####################
    # Structure of tree:
    #      1
    #     / \
    #    2   3
    #   /   /|\
    #  4   5 6 7
    ####################
    %{
      tree: %Node{
        payload: 1,
        children: [
          %Node{
            payload: 2,
            children: [
              %Node{payload: 4, children: []}
            ]
          },
          %Node{
            payload: 3,
            children: [
              %Node{payload: 5, children: []},
              %Node{payload: 6, children: []},
              %Node{payload: 7, children: []}
            ]
          }
        ]
      }
    }
  end

  test "traversing down and up and down works as expected", %{tree: tree} do
    zipper = %Zipper{focus: tree}
    assert zipper.focus.payload == 1
    zipper = Zipper.down(zipper, 0)
    assert zipper.focus.payload == 2
    zipper = Zipper.up(zipper)
    assert zipper.focus.payload == 1
    zipper = Zipper.down(zipper, 1)
    assert zipper.focus.payload == 3
    zipper = Zipper.down(zipper, 1)
    assert zipper.focus.payload == 6
  end
end
