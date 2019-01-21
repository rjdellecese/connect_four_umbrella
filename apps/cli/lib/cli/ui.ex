defmodule CLI.UI do
  @moduledoc """
  Renders the CLI's UI. This should be the **only** way in which the UI is drawn from the CLI,
  except for the prompt.
  """

  require Integer

  @enforce_keys [:game_pid]
  defstruct(game_pid: nil, below_board: "", above_board: "")

  @doc ~S"""
  Get a string containing a visual representation of the board.

  ## Examples

      iex> {:ok, game_pid} = Game.start_link()
      iex> Game.move(game_pid, [3, 3, 3, 4, 4])
      {:ok, %{moves: [3, 3, 3, 4, 4], result: nil}
      iex> board_string = CLI.render(%UI{game_pid: game_pid})
      iex> board_string ==
      ...>   "\n" <>
      ...>   "┌───┬───┬───┬───┬───┬───┬───┐\n" <>
      ...>   "│   │   │   │   │   │   │   │\n" <>
      ...>   "├───┼───┼───┼───┼───┼───┼───┤\n" <>
      ...>   "│   │   │   │   │   │   │   │\n" <>
      ...>   "├───┼───┼───┼───┼───┼───┼───┤\n" <>
      ...>   "│   │   │   │   │   │   │   │\n" <>
      ...>   "├───┼───┼───┼───┼───┼───┼───┤\n" <>
      ...>   "│   │   │   │ ○ │   │   │   │\n" <>
      ...>   "├───┼───┼───┼───┼───┼───┼───┤\n" <>
      ...>   "│   │   │   │ ● │ ○ │   │   │\n" <>
      ...>   "├───┼───┼───┼───┼───┼───┼───┤\n" <>
      ...>   "│   │   │   │ ○ │ ● │   │   │\n" <>
      ...>   "└───┴───┴───┴───┴───┴───┴───┘\n" <>
      ...>   "  1   2   3   4   5   6   7" <>
      ...>   "\n"
      true

  """
  def render(%__MODULE__{game_pid: game_pid, below_board: below_board, above_board: above_board}) do
    {:ok, %{moves: moves}} = Game.look(game_pid)
    board = render_board(moves)
    ui = IO.ANSI.clear() <> above_board <> "\n" <> board <> "\n" <> below_board

    IO.puts(ui)
  end

  @spec render_board(Game.moves()) :: String.t()
  defp render_board(moves) do
    board_data =
      moves
      |> Enum.with_index()
      |> Enum.reduce(
        %{0 => [], 1 => [], 2 => [], 3 => [], 4 => [], 5 => [], 6 => []},
        fn move_with_index, acc ->
          {column, index} = move_with_index
          player_color = if Integer.is_even(index), do: :yellow, else: :red
          Map.update!(acc, column, &(&1 ++ [player_color]))
        end
      )

    "┌───┬───┬───┬───┬───┬───┬───┐\n" <>
      board_row(board_data, 5) <>
      "├───┼───┼───┼───┼───┼───┼───┤\n" <>
      board_row(board_data, 4) <>
      "├───┼───┼───┼───┼───┼───┼───┤\n" <>
      board_row(board_data, 3) <>
      "├───┼───┼───┼───┼───┼───┼───┤\n" <>
      board_row(board_data, 2) <>
      "├───┼───┼───┼───┼───┼───┼───┤\n" <>
      board_row(board_data, 1) <>
      "├───┼───┼───┼───┼───┼───┼───┤\n" <>
      board_row(board_data, 0) <>
      "└───┴───┴───┴───┴───┴───┴───┘\n" <> "  1   2   3   4   5   6   7"
  end

  defp board_row(board_data, row_num) when row_num in 0..5 do
    0..6
    |> Enum.reduce("│", fn column_num, row ->
      row_color_symbol =
        case Enum.at(board_data[column_num], row_num) do
          :yellow -> IO.ANSI.format([:yellow, "○"], true)
          :red -> IO.ANSI.format([:red, "●"], true)
          nil -> " "
        end

      "#{row} #{row_color_symbol} │"
    end)
    |> (&"#{&1}\n").()
  end
end
