defmodule MonteCarloTreeSearchTest do
  use ExUnit.Case, async: true
  doctest MonteCarloTreeSearch

  alias MonteCarloTreeSearch.{Node, Payload, Zipper}

  setup do
    # Moves: [0, 1, 0, 1, 0, 1, 0] Yellow wins
    zipper =
      %Zipper{
        focus: %Node{
          payload: %Payload{state: []},
          children: [
            %Node{
              payload: %Payload{state: [0]},
              children: [
                %Node{
                  payload: %Payload{state: [0, 1]},
                  children: [
                    %Node{
                      payload: %Payload{state: [0, 1, 0]},
                      children: [
                        %Node{
                          payload: %Payload{state: [0, 1, 0, 1]},
                          children: [
                            %Node{
                              payload: %Payload{state: [0, 1, 0, 1, 0]},
                              children: [
                                %Node{
                                  payload: %Payload{state: [0, 1, 0, 1, 0, 1]},
                                  children: [
                                    %Node{
                                      payload: %Payload{state: [0, 1, 0, 1, 0, 1, 0]},
                                      children: []
                                    }
                                  ]
                                }
                              ]
                            }
                          ]
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
      }
      |> Zipper.down(0)
      |> Zipper.down(0)
      |> Zipper.down(0)
      |> Zipper.down(0)
      |> Zipper.down(0)
      |> Zipper.down(0)
      |> Zipper.down(0)

    true = Node.leaf?(zipper.focus)

    %{zipper: zipper}
  end

  test "backpropagating works", %{zipper: zipper} do
    updated_zipper = MonteCarloTreeSearch.backpropagate({zipper, :yellow_wins})
    assert updated_zipper.focus.payload.visits == 1
    assert updated_zipper.focus.payload.reward == 0

    updated_again_zipper = Zipper.down(updated_zipper, 0)
    assert updated_again_zipper.focus.payload.visits == 1
    assert updated_again_zipper.focus.payload.reward == 1
  end
end
