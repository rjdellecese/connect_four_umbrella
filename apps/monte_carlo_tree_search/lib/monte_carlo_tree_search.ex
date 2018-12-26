defmodule MonteCarloTreeSearch do
  @moduledoc """
  Documentation for MonteCarloTreeSearch.

  Maybe create a struct that tracks the combination of zipper with its current focus and the game
  pid with its current state? Those should usually move in tandem as the simulations are taking
  place.

  Game movement should track zipper focus movement, until the game is over and the zipper needs to
  be "rewound".
  """

  require Logger

  alias MonteCarloTreeSearch.{Node, Payload, Zipper}

  @spec start_search([integer()]) :: %Node{}
  def start_search(moves) do
    root_node = %Node{payload: %Payload{state: moves}}

    zipper = %Zipper{focus: root_node}

    node = search(zipper, Time.utc_now())

    Logger.info(fn ->
      "Best move: play in column #{inspect(node.payload.state |> List.last())}"
    end)
  end

  @spec search(%Zipper{}, Time.t()) :: integer()
  def search(zipper, start_time) do
    Logger.info(fn -> "Searching... iteration ##{inspect(zipper.focus.payload.visits)}" end)

    if Time.diff(Time.utc_now(), start_time) < 5 do
      {:ok, game_pid} = Game.start_link(zipper.focus.payload.state)

      {zipper, result} = traverse(zipper, game_pid) |> rollout(game_pid)

      backpropagate(zipper, result) |> search(start_time)
    else
      best_child(zipper)
    end
  end

  @spec traverse(%Zipper{}, pid()) :: %Zipper{}
  def traverse(zipper, game_pid) do
    Logger.info("Traversing...")

    cond do
      # If the node has zero visits, its children haven't been calculated yet.
      zipper.focus.payload.visits == 0 ->
        zipper

      zipper.focus.payload.fully_expanded ->
        pick_best_uct(zipper, game_pid) |> traverse(game_pid)

      true ->
        zipper
    end
  end

  # Gotta figure out where to perform child calculation and record game results better.
  @spec rollout(%Zipper{}, pid()) :: {%Zipper{}, integer()}
  def rollout(zipper, game_pid) do
    Logger.info("Rolling out...")

    zipper_ =
      if is_nil(zipper.focus.children) do
        expand_focused_node(zipper, game_pid)
      else
        zipper
      end

    {new_zipper, result} = rollout_policy(zipper_, game_pid)

    if is_nil(result) do
      rollout(new_zipper, game_pid)
    else
      # The node is a leaf, and has no children.
      new_zipper_ = %{new_zipper | focus: %{zipper.focus | children: []}}
      {new_zipper_, result}
    end
  end

  @spec rollout_policy(%Zipper{}, pid()) :: {%Zipper{}, integer()}
  def rollout_policy(zipper, game_pid) do
    pick_random_unvisited(zipper, game_pid)
  end

  @spec backpropagate(%Zipper{}, integer()) :: %Zipper{}
  def backpropagate(zipper, result) do
    Logger.info("Backpropagating...")
    new_zipper = update_payload(zipper, result)

    if Zipper.root?(new_zipper) do
      new_zipper
    else
      backpropagate(Zipper.up(new_zipper), result)
    end
  end

  @spec update_payload(%Zipper{}, integer()) :: %Zipper{}
  def update_payload(zipper, result) do
    %{
      zipper
      | focus: %{
          zipper.focus
          | payload: %{
              zipper.focus.payload
              | visits: zipper.focus.payload.visits + 1,
                reward: zipper.focus.payload.reward + result,
                fully_expanded: fully_expanded?(zipper.focus)
            }
        }
    }
  end

  @doc """
  Assumes that the node has had its children calculated already.
  """
  @spec fully_expanded?(%Node{}) :: boolean()
  def fully_expanded?(%Node{children: children}) do
    Enum.all?(children, fn child -> child.payload.visits > 0 end)
  end

  @spec best_child(%Zipper{}) :: %Node{}
  def best_child(zipper) do
    Enum.max_by(zipper.focus.children, fn node -> node.payload.visits end)
  end

  @spec pick_best_uct(%Zipper{}, pid()) :: %Node{}
  def pick_best_uct(zipper, game_pid) do
    best_uct_node =
      zipper.focus.children
      |> Enum.with_index()
      |> Enum.max_by(fn {node, _index} -> uct(zipper.focus, node) end)

    {%Node{payload: %Payload{state: moves}}, index} = best_uct_node
    move = List.last(moves)

    Game.move(game_pid, move)
    Zipper.down(zipper, index)
  end

  @doc """
  UCT (Upper Confidence bounds applied to Trees) function.

  References:
  - https://en.wikipedia.org/wiki/Monte_Carlo_tree_search#Exploration_and_exploitation
  - https://www.chessprogramming.org/UCT#Selection
  """
  @spec uct(%Node{}, %Node{}) :: float()
  def uct(parent_node = %Node{}, child_node = %Node{}) do
    child_node_wins = child_node.payload.reward
    child_node_visits = child_node.payload.visits

    win_ratio = child_node_wins / child_node_visits

    exploration_constant = :math.sqrt(2)
    parent_node_visits = parent_node.payload.visits

    win_ratio + exploration_constant +
      :math.sqrt(:math.log(parent_node_visits) / child_node_visits)
  end

  # result integer will be 0 or 1
  @spec pick_random_unvisited(%Zipper{}, pid()) :: {%Zipper{}, integer() | nil}
  def pick_random_unvisited(zipper, game_pid) do
    # if Enum.empty?(zipper.focus.children) do
    #   require IEx
    #   IEx.pry()
    # end

    random_unvisited_child_node =
      zipper.focus.children
      |> Enum.with_index()
      |> Enum.filter(fn {node, _index} -> node.payload.visits == 0 end)
      |> Enum.random()

    {%Node{payload: %Payload{state: moves}}, index} = random_unvisited_child_node
    move = List.last(moves)

    {:ok, %{result: result_atom}} = Game.move(game_pid, move)

    # TODO: Replace this with something better and correct!
    result =
      case result_atom do
        :yellow_wins -> 1
        :red_wins -> 0
        :draw -> 0.5
        nil -> nil
      end

    new_zipper = Zipper.down(zipper, index)

    {new_zipper, result}
  end

  # TODO: Rename!! This isn't "expanding", it's more just like "calculating children". Expanding
  # would be visiting the children.
  def expand_focused_node(zipper, game_pid) do
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
