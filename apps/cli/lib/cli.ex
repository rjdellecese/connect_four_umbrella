defmodule CLI do
  @moduledoc """
  Documentation for CLI.
  """
  @difficulties [0.1, 1, 3]

  @easy Enum.at(@difficulties, 0)
  @medium Enum.at(@difficulties, 1)
  @hard Enum.at(@difficulties, 2)

  alias CLI.UI

  require Integer

  @doc """
  """
  def main(_args) do
    {:ok, game_pid} = Game.start_link()
    start_game(game_pid)
  end

  def start_game(game_pid) do
    IO.ANSI.clear() |> IO.puts()
    move_duration = choose_difficulty()

    above_board = "Game started! You are playing as yellow."

    choose_move(game_pid, move_duration, above_board)
  end

  defp choose_difficulty() do
    IO.puts("How hard do you want it?")

    IO.puts(
      """
      1. Easy (#{@easy}s)
      2. Medium (#{@medium}s)
      3. Hard (#{@hard}s)
      """
      |> String.trim_trailing()
    )

    selection =
      IO.gets("> ")
      |> String.trim()
      |> String.downcase()

    case selection do
      "1" ->
        @easy

      "2" ->
        @medium

      "3" ->
        @hard

      _ ->
        IO.puts("Enter '1', '2', or '3'")
        choose_difficulty()
    end
  end

  defp choose_move(game_pid, move_duration, above_board \\ "") do
    {:ok, %{moves: moves}} = Game.look(game_pid)
    UI.render(%UI{game_pid: game_pid, below_board: "Choose your move.", above_board: above_board})

    IO.gets("> ")
    |> String.trim()
    |> Integer.parse()
    |> make_move(game_pid, move_duration)
  end

  defp make_move({move, _}, game_pid, move_duration) when move in 1..7 do
    result = Game.move(game_pid, move - 1)

    case result do
      {:ok, %{moves: moves, result: result}} ->
        ui = %UI{game_pid: game_pid}

        case result do
          :yellow_wins ->
            UI.render(%{ui | below_board: "You win!"})
            play_again?(game_pid)

          :red_wins ->
            UI.render(%{ui | below_board: "You lose."})
            play_again?(game_pid)

          :draw ->
            UI.render(%{ui | below_board: "Game drawn."})
            play_again?(game_pid)

          nil ->
            UI.render(%{ui | below_board: "The computer is thinking..."})

            ai_move(game_pid, move_duration)
        end

      {:error, "Illegal move"} ->
        above_board = "Illegal move! Try again."
        choose_move(game_pid, move_duration, above_board)
    end
  end

  defp make_move(_move, game_pid, move_duration) do
    above_board = "Invalid move! Try again."
    choose_move(game_pid, move_duration, above_board)
  end

  defp ai_move(game_pid, move_duration) do
    {:ok, %{moves: moves}} = Game.look(game_pid)
    ai_move = MCTS.search(moves, move_duration)
    {:ok, %{result: new_result}} = Game.move(game_pid, ai_move)

    ui = %UI{game_pid: game_pid}

    case new_result do
      :yellow_wins ->
        UI.render(%{ui | below_board: "You win!"})
        play_again?(game_pid)

      :red_wins ->
        UI.render(%{ui | below_board: "You lose."})
        play_again?(game_pid)

      :draw ->
        UI.render(%{ui | below_board: "Game drawn."})
        play_again?(game_pid)

      nil ->
        choose_move(game_pid, move_duration)
    end
  end

  defp play_again?(game_pid, prompt \\ "Play again? (y/n)") do
    IO.puts(prompt)

    IO.gets("> ")
    |> String.trim()
    |> play_again(game_pid)
  end

  defp play_again(response, game_pid) do
    case response do
      "y" ->
        Game.restart(game_pid)
        start_game(game_pid)

      "n" ->
        IO.puts("Good game(s)!")

      _ ->
        play_again?(game_pid, "Enter either 'y' or 'n'")
    end
  end
end
