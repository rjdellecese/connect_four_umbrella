defmodule MCTS.ZipperTest do
  use ExUnit.Case, async: true
  doctest MCTS.Zipper

  alias MCTS.{Node, Zipper}

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

  describe "down/2" do
    test "raises an error when the focus has no children", %{tree: tree} do
      zipper =
        %Zipper{focus: tree}
        |> Zipper.down(0)
        |> Zipper.down(0)

      assert_raise RuntimeError, "focus node has no children", fn ->
        Zipper.down(zipper, 0)
      end
    end

    test "raises an ArgumentError when there is no child at the given index", %{tree: tree} do
      zipper =
        %Zipper{focus: tree}
        |> Zipper.down(1)

      assert_raise ArgumentError, "no child node at index: 3 (index may not be negative)", fn ->
        Zipper.down(zipper, 3)
      end
    end
  end
end
