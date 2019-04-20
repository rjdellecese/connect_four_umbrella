defmodule MCTS do
  @moduledoc """
  A Monte Carlo Tree Search implementation for Connect Four.
  """

  require Integer

  alias MCTS.{Node, Payload, Zipper}

  @typep zipper_with_game_result :: {%Zipper{}, Game.result()}

  @doc """
  Perform a Monte Carlo Tree Search starting at the position provided, searching until the
  specified resource has been depleted. Resource options are `:time` (measured in milliseconds) or
  `:simulations`.

  ## Examples

      iex> move = MCTS.search([], resource: :time, amount: 100)
      iex> Enum.member?(0..6, move)
      true

      iex> move = MCTS.search([], resource: :simulations, amount: 100)
      iex> Enum.member?(0..6, move)
      true

      iex> move = MCTS.search([3, 3, 4, 2, 2, 4, 5], resource: :simulations, amount: 5)
      iex> Enum.member?(0..6, move)
      true

  """
  @spec search(Game.moves(), pos_integer()) :: Game.column()
  def search(moves, options) do
    %{resource: resource, amount: amount} = Enum.into(options, %{})

    unless Enum.member?([:time, :simulations], resource) do
      raise ArgumentError,
            "resource options are `:time` or `:simulations`, got: #{inspect(resource)}"
    end

    unless is_integer(amount) do
      raise ArgumentError, "resource amount must be an integer, got: #{inspect(amount)}"
    end

    root_node = %Node{payload: %Payload{state: moves}}
    zipper = %Zipper{focus: root_node}
    {:ok, game_pid} = Game.start_link()

    node =
      case resource do
        :time ->
          search_for_duration(zipper, Time.utc_now(), amount, game_pid)

        :simulations ->
          search_n_times(zipper, 0, amount, game_pid)
      end

    List.last(node.payload.state)
  end

  @spec search_for_duration(%Zipper{}, Time.t(), pos_integer(), pid()) :: %Node{}
  defp search_for_duration(zipper, start_time, move_duration, game_pid) do
    if Time.diff(Time.utc_now(), start_time, :millisecond) < move_duration do
      Game.restart(game_pid)

      moves = zipper.focus.payload.state
      if Enum.any?(moves), do: Game.move(game_pid, moves)

      zipper
      |> select(game_pid)
      |> simulate(game_pid)
      |> backpropagate()
      |> search_for_duration(start_time, move_duration, game_pid)
    else
      best_child(zipper)
    end
  end

  @spec search_n_times(%Zipper{}, non_neg_integer(), pos_integer(), pid()) :: %Node{}
  defp search_n_times(zipper, simulations_completed, simulations_to_run, game_pid) do
    if simulations_completed < simulations_to_run do
      Game.restart(game_pid)

      moves = zipper.focus.payload.state
      if Enum.any?(moves), do: Game.move(game_pid, moves)

      zipper
      |> select(game_pid)
      |> simulate(game_pid)
      |> backpropagate()
      |> search_n_times(simulations_completed + 1, simulations_to_run, game_pid)
    else
      best_child(zipper)
    end
  end

  @spec select(%Zipper{}, pid()) :: zipper_with_game_result()
  defp select(zipper, game_pid) do
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
    zipper_ =
      if zipper.focus.payload.visits == 0 do
        expand_focused_node(zipper, game_pid)
      else
        zipper
      end

    zipper_
    |> select_random_unvisited(game_pid)
    |> simulate(game_pid)
  end

  defp simulate({zipper, result}, _game_pid) do
    {zipper, result}
  end

  @spec backpropagate(zipper_with_game_result()) :: %Zipper{}
  defp backpropagate({zipper, result}) do
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
        Enum.empty?(moves) ->
          :red

        moves |> length() |> Integer.is_odd() ->
          :yellow

        moves |> length() |> Integer.is_even() ->
          :red
      end

    %{
      zipper
      | focus: %{
          zipper.focus
          | payload: %{
              zipper.focus.payload
              | visits: zipper.focus.payload.visits + 1,
                reward: zipper.focus.payload.reward + reward(result, player),
                fully_expanded: fully_expanded?(zipper.focus)
            }
        }
    }
  end

  @spec reward(Game.result(), Game.player()) :: float()
  defp reward(result, player) do
    case result do
      :yellow_wins ->
        if player == :yellow, do: 1, else: 0

      :red_wins ->
        if player == :red, do: 1, else: 0

      :draw ->
        0.5
    end
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
