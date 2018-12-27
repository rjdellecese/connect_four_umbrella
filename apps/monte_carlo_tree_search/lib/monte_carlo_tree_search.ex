defmodule MonteCarloTreeSearch do
  @moduledoc """
  A Monte Carlo Tree Search implementation for Connect Four.
  """

  require Logger
  require Integer

  alias MonteCarloTreeSearch.{Node, Payload, Zipper}

  @typep zipper_with_game_result :: {%Zipper{}, Game.result()}

  @doc """
  Perform a Monte Carlo Tree Search starting at the position provided, searching for the given
  move duration (5 seconds by default).
  """
  @spec search(Game.moves(), pos_integer()) :: Game.column()
  def search(moves, move_duration \\ 5) do
    root_node = %Node{payload: %Payload{state: moves}}

    zipper = %Zipper{focus: root_node}

    node = search(zipper, Time.utc_now(), move_duration)

    Logger.info(fn ->
      "Best move: play in column #{inspect(node.payload.state |> List.last())}"
    end)

    List.last(node.payload.state)
  end

  @spec search(%Zipper{}, Time.t(), pos_integer()) :: %Node{}
  defp search(zipper, start_time, move_duration) do
    Logger.info(fn -> "Searching... simulation ##{inspect(zipper.focus.payload.visits)}" end)

    if Time.diff(Time.utc_now(), start_time) < move_duration do
      {:ok, game_pid} = Game.start_link(zipper.focus.payload.state)

      select(zipper, game_pid)
      |> simulate(game_pid)
      |> backpropagate()
      |> search(start_time, move_duration)
    else
      best_child(zipper)
    end
  end

  @spec select(%Zipper{}, pid()) :: zipper_with_game_result()
  defp select(zipper, game_pid) do
    Logger.info("Selecting...")

    if zipper.focus.payload.fully_expanded do
      {new_zipper, result} = select_best_uct(zipper, game_pid)

      if is_nil(result) do
        select(new_zipper, game_pid)
      else
        {new_zipper, result}
      end
    else
      {zipper, nil}
    end
  end

  @spec simulate(zipper_with_game_result(), pid()) :: zipper_with_game_result()
  defp simulate({zipper, nil}, game_pid) do
    Logger.info("Simulating...")

    zipper_ =
      if zipper.focus.payload.visits == 0 do
        expand_focused_node(zipper, game_pid)
      else
        zipper
      end

    {new_zipper, result} = select_random_unvisited(zipper_, game_pid)

    if is_nil(result) do
      simulate({new_zipper, nil}, game_pid)
    else
      {new_zipper, result}
    end
  end

  defp simulate({zipper, result}, _game_pid) do
    {zipper, result}
  end

  @spec backpropagate(zipper_with_game_result()) :: %Zipper{}
  defp backpropagate({zipper, result}) do
    Logger.info("Backpropagating...")
    new_zipper = update_payload(zipper, result)

    if Zipper.root?(new_zipper) do
      new_zipper
    else
      backpropagate({Zipper.up(new_zipper), result})
    end
  end

  @spec update_payload(%Zipper{}, Game.result()) :: %Zipper{}
  defp update_payload(zipper, result) do
    moves = zipper.focus.payload.state

    player =
      cond do
        length(moves) == 0 ->
          :red

        length(moves) |> Integer.is_odd() ->
          :yellow

        length(moves) |> Integer.is_even() ->
          :red
      end

    reward =
      case result do
        :yellow_wins ->
          if player == :yellow, do: 1, else: 0

        :red_wins ->
          if player == :red, do: 1, else: 0

        :draw ->
          0.5
      end

    %{
      zipper
      | focus: %{
          zipper.focus
          | payload: %{
              zipper.focus.payload
              | visits: zipper.focus.payload.visits + 1,
                reward: zipper.focus.payload.reward + reward,
                fully_expanded: fully_expanded?(zipper.focus)
            }
        }
    }
  end

  # Assumes that the node has had its children calculated already.
  @spec fully_expanded?(%Node{}) :: boolean()
  defp fully_expanded?(%Node{children: children}) do
    Enum.all?(children, fn child -> child.payload.visits > 0 end)
  end

  @spec best_child(%Zipper{}) :: %Node{}
  defp best_child(zipper) do
    Enum.max_by(zipper.focus.children, fn node -> node.payload.visits end)
  end

  @spec select_best_uct(%Zipper{}, pid()) :: zipper_with_game_result()
  defp select_best_uct(zipper, game_pid) do
    best_uct_node_with_index =
      zipper.focus.children
      |> Enum.with_index()
      |> Enum.max_by(fn {node, _index} -> uct(zipper.focus, node) end)

    select_node(zipper, best_uct_node_with_index, game_pid)
  end

  @spec select_node(%Zipper{}, {%Node{}, 0..6}, pid()) :: zipper_with_game_result()
  defp select_node(zipper = %Zipper{}, node_with_index, game_pid) do
    {%Node{payload: %Payload{state: moves}}, index} = node_with_index
    move = List.last(moves)

    {:ok, %{result: result}} = Game.move(game_pid, move)

    new_zipper = Zipper.down(zipper, index)

    {new_zipper, result}
  end

  # UCT (Upper Confidence bounds applied to Trees) function.
  #
  # References:
  # - https://en.wikipedia.org/wiki/Monte_Carlo_tree_search#Exploration_and_exploitation
  # - https://www.chessprogramming.org/UCT#Selection
  @spec uct(%Node{}, %Node{}) :: float()
  defp uct(parent_node = %Node{}, child_node = %Node{}) do
    child_node_wins = child_node.payload.reward
    child_node_visits = child_node.payload.visits

    win_ratio = child_node_wins / child_node_visits

    exploration_constant = :math.sqrt(2)
    parent_node_visits = parent_node.payload.visits

    win_ratio + exploration_constant +
      :math.sqrt(:math.log(parent_node_visits) / child_node_visits)
  end

  @spec select_random_unvisited(%Zipper{}, pid()) :: zipper_with_game_result()
  defp select_random_unvisited(zipper, game_pid) do
    random_unvisited_child_node_with_index =
      zipper.focus.children
      |> Enum.with_index()
      |> Enum.filter(fn {node, _index} -> node.payload.visits == 0 end)
      |> Enum.random()

    select_node(zipper, random_unvisited_child_node_with_index, game_pid)
  end

  @spec expand_focused_node(%Zipper{}, pid()) :: %Zipper{}
  defp expand_focused_node(zipper, game_pid) do
    {:ok, legal_moves} = Game.legal_moves(game_pid)

    %{
      zipper
      | focus: %{
          zipper.focus
          | children:
              Enum.map(legal_moves, fn legal_move ->
                %Node{payload: %Payload{state: zipper.focus.payload.state ++ [legal_move]}}
              end)
        }
    }
  end
end
