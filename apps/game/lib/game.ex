defmodule Game do
  @moduledoc """
  A Connect Four game.

  Players are distinguished by game piece color (yellow and red). Moves are represented by the
  columns in which they are made.

  Yellow moves first.

  This implementation is based on an efficient implementation written by John Tromp, which uses
  bitboards to be very small and very fast.

  This is how it works:
  [https://github.com/denkspuren/BitboardC4/blob/master/BitboardDesign.md](https://github.com/denkspuren/BitboardC4/blob/master/BitboardDesign.md)

  Original Java implementation:
  [https://tromp.github.io/c4/Connect4.java](https://tromp.github.io/c4/Connect4.java)
  """

  import Bitwise

  use GenServer

  defstruct(
    bitboards: %{yellow: 0, red: 0},
    column_heights: %{0 => 0, 1 => 7, 2 => 14, 3 => 21, 4 => 28, 5 => 35, 6 => 42},
    moves: [],
    plies: 0,
    result: nil
  )

  @type t :: %__MODULE__{
          bitboards: %{required(:yellow) => integer(), required(:red) => integer()},
          column_heights: column_heights(),
          moves: moves(),
          plies: non_neg_integer(),
          result: result()
        }

  @typedoc """
  One of seven Connect Four game columns.
  """
  @type column :: 0..6

  @typedoc """
  A list of Connect Four moves, describing a game.
  """
  @type moves :: [column()]

  @typedoc """
  A Connect Four player (yellow always moves first).
  """
  @type player :: :yellow | :red

  @typedoc """
  A Connect Four game result. `nil` means that the game has not yet ended. `:draw`s occur when all
  columns are full and no player has connected four.
  """
  @type result :: :yellow_wins | :red_wins | :draw | nil

  @typep column_heights :: %{
           required(0) => non_neg_integer(),
           required(1) => non_neg_integer(),
           required(2) => non_neg_integer(),
           required(3) => non_neg_integer(),
           required(4) => non_neg_integer(),
           required(5) => non_neg_integer(),
           required(6) => non_neg_integer()
         }

  ############
  # Public API
  ############

  @doc """
  Start a GenServer process for a Connect Four game.

  ## Examples

      iex> {:ok, pid} = Game.start_link()
      iex> Process.alive?(pid)
      true

  """
  @spec start_link() :: GenServer.on_start()
  def start_link(), do: GenServer.start_link(__MODULE__, nil)

  @doc """
  Submit a move for whomever's turn it currently is by specifying a column (0 through 6).

  Make multiple moves at once by passing a list of moves. If any of the moves are invalid, none
  (including any valid ones preceding the invalid one) will be played.

  `moves` is a list of all the moves completed in the game so far. Moves are
  represented as integers between 0 and 6, each reflecting the column in which
  the piece for that turn was dropped. The first integer in the list is yellow's
  move, the second is red's, the third is yellow's, and so on.

  Game results are reported as atoms and can be one of the following:
    - `nil` (when the game is still in progress)
    - `:yellow_wins`
    - `:red_wins`
    - `:draw` (when the board fills up without four connected pieces)

  ## Examples

      iex> {:ok, pid} = Game.start_link()
      iex> Game.move(pid, 4)
      {:ok, %{moves: [4], result: nil}}
      iex> Game.move(pid, 5)
      {:ok, %{moves: [4, 5], result: nil}}

      iex> {:ok, pid} = Game.start_link()
      iex> Game.move(pid, [4, 5])
      {:ok, %{moves: [4, 5], result: nil}}

  """
  @spec move(pid(), column() | moves()) ::
          {:ok, %{moves: moves(), result: result()}} | {:error, String.t()}
  def move(pid, column) when is_integer(column), do: GenServer.call(pid, {:move, column})

  def move(pid, moves) when is_list(moves), do: GenServer.call(pid, {:move, moves})

  @doc """
  Get a list of legal moves for the current position.

  ## Examples

      iex> {:ok, pid} = Game.start_link()
      iex> Game.legal_moves(pid)
      {:ok, [0, 1, 2, 3, 4, 5, 6]}

      iex> {:ok, pid} = Game.start_link()
      iex> Game.move(pid, [3, 3, 3, 3, 3, 3])
      {:ok, %{moves: [3, 3, 3, 3, 3, 3], result: nil}}
      iex> Game.legal_moves(pid)
      {:ok, [0, 1, 2, 4, 5, 6]}

  """
  @spec legal_moves(pid()) :: {:ok, moves()}
  def legal_moves(pid), do: GenServer.call(pid, :legal_moves)

  @doc """
  Look at the state of the game.

  ## Examples

      iex> {:ok, pid} = Game.start_link()
      iex> Game.move(pid, [4, 5, 4])
      {:ok, %{moves: [4, 5, 4], result: nil}}
      iex> Game.look(pid)
      {:ok, %{moves: [4, 5, 4], result: nil}}

  Works for finished games, too.

  ## Examples

      iex> {:ok, pid} = Game.start_link()
      iex> Game.move(pid, [4, 5, 4, 5, 4, 5])
      {:ok, %{moves: [4, 5, 4, 5, 4, 5], result: nil}}
      iex> Game.move(pid, 4)
      {:ok, %{moves: [4, 5, 4, 5, 4, 5, 4], result: :yellow_wins}}
      iex> Game.look(pid)
      {:ok, %{moves: [4, 5, 4, 5, 4, 5, 4], result: :yellow_wins}}

  """
  @spec look(pid()) :: {:ok, %{moves: moves(), result: result()}}
  def look(pid), do: GenServer.call(pid, :look)

  @doc """
  Restart the game. The game does **not** need to have a result to be restarted.

  ## Examples

      iex> {:ok, pid} = Game.start_link()
      iex> Game.move(pid, 4)
      {:ok, %{moves: [4], result: nil}}
      iex> Game.restart(pid)
      :ok
      iex> Game.move(pid, 4)
      {:ok, %{moves: [4], result: nil}}

  """
  @spec restart(pid()) :: :ok
  def restart(pid), do: GenServer.call(pid, :restart)

  ##################
  # Server callbacks
  ##################

  @impl true
  @spec init(nil) :: {:ok, __MODULE__.t()} | {:ok, %{result: result()}}
  def init(_init_arg), do: {:ok, %__MODULE__{}}

  @impl true
  @spec handle_call({:move, column() | moves()}, GenServer.from(), __MODULE__.t()) ::
          {:reply,
           {:ok, %{moves: moves(), result: result()}, __MODULE__.t()} | {:error, String.t()},
           __MODULE__.t()}
  def handle_call({:move, column}, _from, game = %__MODULE__{}) when is_integer(column) do
    cond do
      !is_nil(game.result) ->
        {:reply, {:error, "Game is over"}, game}

      legal_move?(column, game.column_heights) ->
        updated_game = make_move(column, game)

        {:reply, {:ok, %{moves: updated_game.moves, result: updated_game.result}}, updated_game}

      true ->
        {:reply, {:error, "Illegal move"}, game}
    end
  end

  def handle_call({:move, moves}, _from, game = %__MODULE__{}) when is_list(moves) do
    case make_many_moves(moves, game) do
      {:ok, updated_game} ->
        {:reply, {:ok, %{moves: updated_game.moves, result: updated_game.result}}, updated_game}

      {:error, message} ->
        {:reply, {:error, message}, game}
    end
  end

  @impl true
  @spec handle_call(:legal_moves, GenServer.from(), __MODULE__.t()) ::
          {:reply, {:ok, moves()}, __MODULE__.t()}
  def handle_call(:legal_moves, _from, game = %__MODULE__{}) do
    {:reply, {:ok, list_legal_moves(game.column_heights)}, game}
  end

  @impl true
  @spec handle_call(:look, GenServer.from(), __MODULE__.t()) ::
          {:reply, :ok, %{moves: moves(), result: result()}}
  def handle_call(:look, _from, game = %__MODULE__{}) do
    {:reply, {:ok, %{moves: game.moves, result: game.result}}, game}
  end

  @impl true
  @spec handle_call(:restart, GenServer.from(), __MODULE__.t()) :: {:reply, :ok, __MODULE__.t()}
  def handle_call(:restart, _from, _game) do
    {:reply, :ok, %__MODULE__{}}
  end

  ##############
  # Game logic
  ##############

  @spec make_move(column(), __MODULE__.t()) :: __MODULE__.t()
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

  @spec set_result(__MODULE__.t()) :: __MODULE__.t()
  defp set_result(updated_game = %__MODULE__{}) do
    cond do
      connected_four?(updated_game) ->
        %{updated_game | result: winning_color(updated_game)}

      updated_game.plies == 42 ->
        %{updated_game | result: :draw}

      true ->
        updated_game
    end
  end

  @spec color_to_move(__MODULE__.t()) :: Game.player()
  defp color_to_move(%__MODULE__{plies: plies}) do
    case plies &&& 1 do
      0 -> :yellow
      1 -> :red
    end
  end

  @spec color_last_moved(__MODULE__.t()) :: Game.player()
  defp color_last_moved(%__MODULE__{plies: plies}) do
    case plies &&& 1 do
      1 -> :yellow
      0 -> :red
    end
  end

  @spec make_many_moves(moves(), __MODULE__.t()) :: {:ok, __MODULE__.t()} | {:error, String.t()}
  defp make_many_moves([next_move | remaining_moves], game = %__MODULE__{}) do
    if legal_move?(next_move, game.column_heights) do
      updated_game = make_move(next_move, game)
      make_many_moves(remaining_moves, updated_game)
    else
      {:error, "One or more invalid moves"}
    end
  end

  defp make_many_moves([], game = %__MODULE__{}) do
    {:ok, game}
  end

  @spec legal_move?(column(), column_heights()) :: boolean()
  defp legal_move?(column, column_heights) do
    Enum.member?(list_legal_moves(column_heights), column)
  end

  @spec connected_four?(__MODULE__.t()) :: boolean()
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

  @spec list_legal_moves(column_heights()) :: [integer()]
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
end
