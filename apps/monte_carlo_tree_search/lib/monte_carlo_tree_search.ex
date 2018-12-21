defmodule MonteCarloTreeSearch do
  @moduledoc """
  Documentation for MonteCarloTreeSearch.
  """

  alias MonteCarloTreeSearch.{Game, Node, Payload, Zipper}

  @spec search([integer()]) :: integer()
  def start_search(moves) do
    {:ok, game_pid} = Game.start_link(moves)

    root_node = %Node{
      payload: %Payload{state: moves},
      children:
        Game.legal_moves(game_pid)
        |> Enum.map(fn legal_move -> %Node{payload: %Payload{state: moves ++ [legal_move]}} end)
    }

    zipper = %Zipper{focus: root_node}

    search(zipper, game_pid, Time.utc_now())
  end

  @spec search(%Zipper{}, pid(), Time.t()) :: integer()
  def search(zipper, game_pid, start_time) do
    if Time.diff(start_time, Time.utc_now()) < 5 do
      {zipper, result} = traverse(zipper, game_pid) |> rollout(game_pid)

      backpropagate(zipper, result) |> search(game_pid, start_time)
    else
      best_child(zipper)
    end
  end

  def traverse(zipper, game_pid) do
    node = zipper.focus

    cond do
      node.payload.fully_expanded ->
        pick_best_uct(zipper, game_pid) |> traverse(game_pid)

      node.payload.visits == 0 ->
        zipper

      true ->
        pick_unvisited(zipper, game_pid)
    end
  end

  @spec rollout(%Zipper{}, pid()) :: {%Zipper{}, integer()}
  def rollout(zipper, game_pid) do
    expanded_zipper = expand_focused_node(zipper, game_pid)

    # I believe this will need to have been rolled out at least once before it is possible for
    # this branch to run.
    if Node.leaf?(expanded_zipper.focus) do
      result(node)
    else
      {new_zipper, result} = rollout_policy(expanded_zipper, game_pid)

      if is_nil(result) do
        rollout(new_zipper, game_pid)
      else
        {new_zipper, result}
      end
    end
  end

  @spec rollout_policy(%Zipper{}, pid()) :: {%Zipper{}, integer()}
  def rollout_policy(zipper, game_pid) do
    pick_random(zipper, game_pid)
  end

  @spec backpropagate(%Zipper{}, integer()) :: %Zipper{}
  def backpropagate(zipper, result) do
    new_zipper = update_payload(zipper, result) |> Zipper.up(zipper)

    # Could replace this with backpropagate(nil, result)
    if is_nil(new_zipper) do
      zipper
    else
      backpropagate(zipper, result)
    end
  end

  @spec update_payload(%Zipper{}, integer()) :: %Zipper{}
  def update_payload(zipper, result) do
    %{
      zipper
      | focus: %Node{
          payload: %{
            zipper.focus.payload
            | visits: zipper.focus.payload.visits + 1,
              reward: zipper.focus.payload.reward + result
          },
          children: zipper.focus.children
        }
    }
  end

  # TODO: Implement!
  def best_child() do
  end

  # TODO: Implement!
  def pick_best_uct(zipper, game_pid) do
    zipper.focus.children
    |> Enum.with_index()

    # Game.move(game_pid, 0)
    Zipper.down(zipper, 0)
  end

  # Pick a random child with 0 visits
  def pick_unvisited(zipper, game_pid) do
    random_unvisited_child_node =
      zipper.focus.children
      |> Enum.filter(fn node -> node.payload.visits == 0 end)
      |> Enum.with_index()
      |> Enum.random()

    {%Node{payload: %Payload{state: moves}}, index} = random_unvisited_child_node
    move = List.last(moves)

    # Game.move(game_pid, move)
    Zipper.down(zipper, index)
  end

  # result integer will be 0 or 1
  @spec pick_random(%Zipper{}, pid()) :: {%Zipper{}, integer()}
  def pick_random(zipper, game_pid) do
    random_child_node_index =
      zipper.focus.children
      |> Enum.with_index()
      |> Enum.values()
      |> Enum.random()

    %{result: result} = Game.move(game_pid, random_child_node_index)
    new_zipper = Zipper.down(zipper, random_child_node_index)

    {new_zipper, result}
  end

  def expand_focused_node(zipper, game_pid) do
    expanded_node = %{
      zipper.focus
      | children:
          Game.legal_moves(game_pid)
          |> Enum.map(fn legal_move ->
            %Node{payload: %Payload{state: node.payload.state ++ [legal_move]}}
          end)
    }

    %{zipper | focus: expanded_node}
  end

  # TODO: Implement!
  def result(node) do
    # Check who won?
    node
  end
end
