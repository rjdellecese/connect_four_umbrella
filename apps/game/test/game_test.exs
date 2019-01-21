defmodule GameTest do
  use ExUnit.Case, async: true
  doctest Game

  setup do
    {:ok, game} = Game.start_link()
    %{game: game}
  end

  test "connects four horizontally _", %{game: game} do
    Enum.each([1, 1, 2, 2, 3, 3], &Game.move(game, &1))

    {:ok, %{result: result}} = Game.move(game, 4)

    assert result == :yellow_wins
  end

  test "connects four vertically |", %{game: game} do
    Enum.each([0, 6, 5, 6, 5, 6, 5], &Game.move(game, &1))

    {:ok, %{result: result}} = Game.move(game, 6)

    assert result == :red_wins
  end

  test "connects four diagonally backwards \\", %{game: game} do
    Enum.each([5, 4, 4, 5, 3, 3, 3, 2, 2, 2], &Game.move(game, &1))

    {:ok, %{result: result}} = Game.move(game, 2)

    assert result == :yellow_wins
  end

  test "connects four diagonally forwards /", %{game: game} do
    Enum.each([6, 1, 2, 2, 1, 3, 3, 3, 4, 4, 4], &Game.move(game, &1))

    {:ok, %{result: result}} = Game.move(game, 4)

    assert result == :red_wins
  end

  test "reports a draw", %{game: game} do
    Enum.each(
      [0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1] ++
        [2, 3, 2, 3, 3, 2, 3, 2, 2, 3, 2, 3] ++
        [4, 5, 4, 5, 5, 4, 5, 4, 4, 5, 4, 5] ++ [6, 6, 6, 6, 6],
      &Game.move(game, &1)
    )

    {:ok, %{result: result}} = Game.move(game, 6)

    assert result == :draw
  end

  test "disallows out-of-bounds moves", %{game: game} do
    {status, _msg} = Game.move(game, 7)

    assert status == :error
  end

  test "disallows moves in columns that are full", %{game: game} do
    Enum.each([0, 0, 0, 0, 0, 0], &Game.move(game, &1))

    {status, _msg} = Game.move(game, 0)

    assert status == :error
  end
end
