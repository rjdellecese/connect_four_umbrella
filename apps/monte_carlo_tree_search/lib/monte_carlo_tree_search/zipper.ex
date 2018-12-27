defmodule MonteCarloTreeSearch.Zipper do
  @moduledoc """
  A zipper tree.
  """

  alias MonteCarloTreeSearch.{Breadcrumb, Node}

  @enforce_keys [:focus]
  defstruct(focus: nil, breadcrumbs: [])

  @type t :: %__MODULE__{focus: %Node{}, breadcrumbs: [%Breadcrumb{}]}

  @spec root?(%__MODULE__{}) :: boolean()
  def root?(zipper = %__MODULE__{}) do
    Enum.empty?(zipper.breadcrumbs)
  end

  @doc """
  Returns nil if the zipper's focus is the root node.
  """
  @spec up(%__MODULE__{}) :: %__MODULE__{} | nil
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

  @spec down(%__MODULE__{}, non_neg_integer()) :: %__MODULE__{} | nil
  def down(zipper = %__MODULE__{}, index) when is_integer(index) do
    if(index < 0 || index >= length(zipper.focus.children)) do
      raise ArgumentError, message: "invalid index (out of bounds)"
    end

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

  @spec break([%Node{}], non_neg_integer()) :: {[%Node{}], %Node{}, [%Node{}]}
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
