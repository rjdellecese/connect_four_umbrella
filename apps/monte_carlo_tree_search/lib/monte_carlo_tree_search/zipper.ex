defmodule MonteCarloTreeSearch.Zipper do
  @moduledoc """
  The focus of a zipper tree.
  """

  alias MonteCarloTreeSearch.{Breadcrumb, Node}

  @enforce_keys [:focus]
  defstruct(focus: nil, breadcrumbs: [])

  @spec root?(%__MODULE__{}) :: boolean()
  def root?(zipper = %__MODULE__{}) do
    List.empty?(zipper.breadcrumbs)
  end

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

  # TODO: Implement nil return case
  @spec down(%__MODULE__{}, integer()) :: %__MODULE__{} | nil
  def down(zipper = %__MODULE__{}, index) do
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

  @spec break([%Node{}], integer()) :: {[%Node{}], %Node{}, [%Node{}]}
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
