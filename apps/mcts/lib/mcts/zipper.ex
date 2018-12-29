defmodule MCTS.Zipper do
  @moduledoc """
  A zipper tree.
  """

  alias MCTS.{Breadcrumb, Node}

  @enforce_keys [:focus]
  defstruct(focus: nil, breadcrumbs: [])

  @type t :: %__MODULE__{focus: Node.t(), breadcrumbs: [Breadcrumb.t()]}

  @spec root?(__MODULE__.t()) :: boolean()
  def root?(zipper = %__MODULE__{}) do
    Enum.empty?(zipper.breadcrumbs)
  end

  @doc """
  Returns nil if the zipper's focus is the root node.
  """
  @spec up(__MODULE__.t()) :: __MODULE__.t() | nil
  def up(zipper = %__MODULE__{}) do
    if root?(zipper) do
      nil
    else
      [last_breadcrumb | remaining_breadcrumbs] = zipper.breadcrumbs

      %{
        zipper
        | focus: %Node{
            payload: last_breadcrumb.payload,
            children: last_breadcrumb.left_nodes ++ [zipper.focus] ++ last_breadcrumb.right_nodes
          },
          breadcrumbs: remaining_breadcrumbs
      }
    end
  end

  @doc """
  Moves the zipper's focus down to the child at the given index.

  Raises a `RuntimeError` if the zipper's focus has no children, and an `ArgumentError` if no
  child exists at the given index.
  """
  @spec down(__MODULE__.t(), non_neg_integer()) :: __MODULE__.t()
  def down(zipper = %__MODULE__{}, index) when is_integer(index) do
    cond do
      Enum.empty?(zipper.focus.children) ->
        # Raise a custom exception here?
        raise "focus node has no children"

      index >= length(zipper.focus.children) ->
        raise ArgumentError,
          message: "no child node at index: #{index} (index may not be negative)"

      true ->
        {left_nodes, new_focus, right_nodes} = break(zipper.focus.children, index)

        %{
          zipper
          | focus: new_focus,
            breadcrumbs: [
              %Breadcrumb{
                payload: zipper.focus.payload,
                left_nodes: left_nodes,
                right_nodes: right_nodes
              }
              | zipper.breadcrumbs
            ]
        }
    end
  end

  @spec break([Node.t()], non_neg_integer()) :: {[Node.t()], Node.t(), [Node.t()]}
  defp break(nodes, index) do
    left_items =
      if index == 0 do
        []
      else
        Enum.slice(nodes, 0, index)
      end

    {
      left_items,
      Enum.at(nodes, index),
      Enum.slice(nodes, (index + 1)..-1)
    }
  end
end
