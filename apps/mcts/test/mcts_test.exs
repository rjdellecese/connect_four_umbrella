defmodule MCTSTest do
  use ExUnit.Case, async: true
  doctest MCTS

  test "searching from the start of the game works" do
    move = MCTS.search([])

    assert Enum.member?(0..6, move)
  end

  test "searching from the start of the game with a shorter duration works" do
    move = MCTS.search([], 1)

    assert Enum.member?(0..6, move)
  end

  test "searching from a game in progress works" do
    move = MCTS.search([3, 3, 4, 2, 2, 4, 5])

    assert Enum.member?(0..6, move)
  end

  test "searching near a winning move works" do
    move = MCTS.search([0, 1, 0, 1, 0, 1])

    assert Enum.member?(0..6, move)
  end
end
