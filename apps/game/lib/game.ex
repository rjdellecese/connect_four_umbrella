defmodule Game do
  @moduledoc """
  A Connect Four game.

  Players are distinguished by game piece color (yellow and red).

  Yellow moves first.

  This is how it works:
  https://github.com/denkspuren/BitboardC4/blob/master/BitboardDesign.md

  Original Java implementation:
  https://tromp.github.io/c4/Connect4.java
  """

  import Bitwise

  use GenServer

  defstruct(
    column_heights: %{0 => 0, 1 => 7, 2 => 14, 3 => 21, 4 => 28, 5 => 35, 6 => 42},
    moves: [],
    plies: 0,
    bitboards: %{yellow: 0, red: 0},
    result: nil
  )

  @type player :: :yellow | :red
  @type result :: :yellow_wins | :red_wins | :draw | nil

  ############
  # Public API
  ############

  @doc """
  Start a GenServer process with an optional initial game state (the `moves`
  argument).

  `moves` is a list of all the moves completed in the game so far. Moves are
  represented as integers between 0 and 6, each reflecting the column in which
  the piece for that turn was dropped. The first integer in the list is yellow's
  move, the second is red's, the third is yellow's, and so on.

  ## Examples

      iex> {:ok, pid} = Game.start_link()
      iex> is_pid(pid)
      true

      iex> {:ok, pid} = Game.start_link([4, 3])
      iex> is_pid(pid)
      true

  """
  @spec start_link([integer()]) :: GenServer.on_start()
  def start_link(moves \\ []), do: GenServer.start_link(__MODULE__, moves)

  @doc """
  Submit a move for whomever's turn it currently is by specifying a column.

  ## Examples

      iex> {:ok, pid} = Game.start_link()
      iex> Game.move(pid, 4)
      {:ok, %{moves: [4], result: nil}}
      iex> Game.move(pid, 5)
      {:ok, %{moves: [4, 5], result: nil}}

  The server is stopped after a move is played which ends the game.

  Game results are reported as atoms and can be one of the following:
      - `nil` (when the game is still in progress)
      - `:yellow_wins`
      - `:red_wins`
      - `:draw` (when the board fills up without four connected pieces)
  """
  @spec move(pid(), integer()) ::
          {:ok, %{moves: [integer()], result: nil | :yellow_wins | :red_wins | :draw}}
  def move(pid, column), do: GenServer.call(pid, {:move, column})

  @doc """
  Get a list of legal moves for the current position.

  ## Examples

      iex> {:ok, pid} = Game.start_link()
      iex> Game.legal_moves(pid)
      {:ok, [0, 1, 2, 3, 4, 5, 6]}

      iex> {:ok, pid} = Game.start_link([3, 3, 3, 3, 3, 3])
      iex> Game.legal_moves(pid)
      {:ok, [0, 1, 2, 4, 5, 6]}

  """
  @spec legal_moves(pid()) :: {:ok, [integer()]}
  def legal_moves(pid), do: GenServer.call(pid, :legal_moves)

  @doc """
  Get a string containing a visual representation of the board.

  ## Examples

  iex> {:ok, pid} = Game.start_link([3, 3, 3, 4, 4])
  iex> {:ok, board_string} = Game.visualize_board(pid)
  iex> board_string ==
  ...>   ". . . . . . .\\n" <>
  ...>   ". . . . . . .\\n" <>
  ...>   ". . . . . . .\\n" <>
  ...>   ". . . y . . .\\n" <>
  ...>   ". . . r y . .\\n" <>
  ...>   ". . . y r . .\\n" <>
  ...>   "-------------\\n" <>
  ...>   "0 1 2 3 4 5 6"
  true

  """
  @spec visualize_board(pid()) :: {:ok, String.t()}
  def visualize_board(pid), do: GenServer.call(pid, :visualize_board)

  # FOR DEBUGGING
  def get_state(pid), do: GenServer.call(pid, :get_state)

  ##################
  # Server callbacks
  ##################

  @impl true
  @spec init(%__MODULE__{}) :: {:ok, %__MODULE__{}} | {:stop, String.t()}
  def init(moves \\ []) do
    if Enum.empty?(moves) do
      {:ok, %__MODULE__{}}
    else
      game_load_result = load_game(moves)

      case game_load_result do
        {:ok, loaded_game} ->
          if loaded_game.result do
            {:stop, "Game ended with result: #{loaded_game.result}"}
          else
            {:ok, loaded_game}
          end

        {:error, message} ->
          {:stop, message}
      end
    end
  end

  @impl true
  @spec handle_call({:move, integer()}, GenServer.from(), %__MODULE__{}) ::
          {:reply, {:ok, %__MODULE__{}}, %__MODULE__{}}
  def handle_call({:move, column}, _from, game = %__MODULE__{}) do
    if legal_move?(column, game.column_heights) do
      updated_game = make_move(column, game)

      if updated_game.result do
        {:stop, :normal, {:ok, %{moves: updated_game.moves, result: updated_game.result}},
         updated_game}
      else
        {:reply, {:ok, %{moves: updated_game.moves, result: updated_game.result}}, updated_game}
      end
    else
      {:reply, {:error, "Illegal move"}, game}
    end
  end

  @impl true
  @spec handle_call(:legal_moves, GenServer.from(), %__MODULE__{}) ::
          {:reply, {:ok, [integer()]}, %__MODULE__{}}
  def handle_call(:legal_moves, _from, game = %__MODULE__{}) do
    {:reply, {:ok, list_legal_moves(game.column_heights)}, game}
  end

  @impl true
  @spec handle_call(:visualize_board, GenServer.from(), %__MODULE__{}) ::
          {:reply, {:ok, String.t()}, %__MODULE__{}}
  def handle_call(:visualize_board, _from, game = %__MODULE__{}) do
    {:reply, {:ok, print_board(game)}, game}
  end

  # TODO: Remove!
  # For debugging
  @impl true
  def handle_call(:get_state, _from, game = %__MODULE__{}) do
    {:reply, {:ok, game}, game}
  end

  ##############
  # Game logic
  ##############

  @spec make_move(integer(), %__MODULE__{}) :: %__MODULE__{}
  defp make_move(column, game = %__MODULE__{}) do
    {old_column_height, new_column_heights} =
      Map.get_and_update!(game.column_heights, column, fn column_height ->
        {column_height, column_height + 1}
      end)

    bitboard_color = color_to_move(game)
    old_bitboard = Map.get(game.bitboards, bitboard_color)
    new_moves = game.moves ++ [column]
    new_bitboard = old_bitboard ^^^ (1 <<< old_column_height)
    new_plies = game.plies + 1

    updated_game = %{
      game
      | :moves => new_moves,
        :plies => new_plies,
        :bitboards => %{game.bitboards | bitboard_color => new_bitboard},
        :column_heights => new_column_heights
    }

    set_result(updated_game)
  end

  @spec set_result(%__MODULE__{}) :: %__MODULE__{}
  defp set_result(updated_game = %__MODULE__{}) do
    cond do
      connected_four?(updated_game) ->
        %{updated_game | result: winning_color(updated_game)}

      length(updated_game.moves) == 42 ->
        %{updated_game | result: :draw}

      true ->
        updated_game
    end
  end

  @spec color_to_move(%__MODULE__{}) :: :yellow | :red
  defp color_to_move(%__MODULE__{plies: plies}) do
    case plies &&& 1 do
      0 -> :yellow
      1 -> :red
    end
  end

  @spec color_last_moved(%__MODULE__{}) :: :yellow | :red
  defp color_last_moved(%__MODULE__{plies: plies}) do
    case plies &&& 1 do
      1 -> :yellow
      0 -> :red
    end
  end

  @spec load_game([integer()], %__MODULE__{}) :: {:ok, %__MODULE__{}} | {:error, String.t()}
  defp load_game(moves, game \\ %__MODULE__{})

  defp load_game([next_move | remaining_moves], game = %__MODULE__{}) do
    if legal_move?(next_move, game.column_heights) do
      updated_game = make_move(next_move, game)
      load_game(remaining_moves, updated_game)
    else
      {:error, "Invalid game"}
    end
  end

  @spec load_game([], %__MODULE__{}) :: {:ok, %__MODULE__{}}
  defp load_game([], game = %__MODULE__{}) do
    {:ok, game}
  end

  @spec legal_move?(integer(), [integer()]) :: boolean()
  defp legal_move?(column, column_heights) do
    Enum.member?(list_legal_moves(column_heights), column)
  end

  @spec connected_four?(%__MODULE__{}) :: boolean()
  defp connected_four?(game = %__MODULE__{}) do
    bitboard = Map.get(game.bitboards, color_last_moved(game))

    direction_offsets = [1, 7, 6, 8]

    Enum.any?(direction_offsets, fn direction_offset ->
      intermediate_bitboard = bitboard &&& bitboard >>> direction_offset
      (intermediate_bitboard &&& intermediate_bitboard >>> (2 * direction_offset)) != 0
    end)
  end

  defp winning_color(%__MODULE__{plies: plies}) do
    case plies &&& 1 do
      1 -> :yellow_wins
      0 -> :red_wins
    end
  end

  @spec list_legal_moves([integer()]) :: [integer()]
  defp list_legal_moves(column_heights) do
    full_top = 0b1000000_1000000_1000000_1000000_1000000_1000000_1000000

    Enum.reduce(0..6, [], fn column, legal_moves_ ->
      if (full_top &&& 1 <<< column_heights[column]) == 0 do
        legal_moves_ ++ [column]
      else
        legal_moves_
      end
    end)
  end

  #####################
  # Board visualization
  #####################

  @spec print_board(%__MODULE__{}) :: String.t()
  defp print_board(game = %__MODULE__{}) do
    red_bitboard_string = print_bitboard(game.bitboards.red)
    yellow_bitboard_string = print_bitboard(game.bitboards.yellow)

    board_string =
      Enum.reduce(0..41, "", fn n, board_string_ ->
        next_char =
          cond do
            String.at(red_bitboard_string, n) == "1" -> "r"
            String.at(yellow_bitboard_string, n) == "1" -> "y"
            true -> "."
          end

        board_string_ <> next_char
      end)

    transpose_board_string_with_newlines(board_string)
  end

  defp print_bitboard(bitboard) do
    Integer.to_string(bitboard, 2)
    |> String.reverse()
    |> pad_bitboard_string
    # TODO: Come up with a better way to do the below
    |> (fn padded_bitboard_string ->
          String.slice(padded_bitboard_string, 0..5) <>
            String.slice(padded_bitboard_string, 7..12) <>
            String.slice(padded_bitboard_string, 14..19) <>
            String.slice(padded_bitboard_string, 21..26) <>
            String.slice(padded_bitboard_string, 28..33) <>
            String.slice(padded_bitboard_string, 35..40) <>
            String.slice(padded_bitboard_string, 42..47)
        end).()
  end

  defp pad_bitboard_string(bitboard_string) do
    bitboard_string_length = String.length(bitboard_string)

    pad_amount =
      if bitboard_string_length >= 48 do
        0
      else
        48 - bitboard_string_length
      end

    String.pad_trailing(bitboard_string, pad_amount, ["0"])
  end

  defp transpose_board_string_with_newlines(board_string) do
    Enum.reduce(0..41, "", fn n, transposed_board_string ->
      transposed_board_string <>
        String.at(board_string, 5 - div(n, 7) + rem(n, 7) * 6) <>
        if rem(n, 7) == 6 do
          "\n"
        else
          " "
        end
    end) <> "-------------\n0 1 2 3 4 5 6"
  end
end
