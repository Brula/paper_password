defmodule PaperPasswordWeb.Stack do
  @moduledoc """
  Where a run opens on screen, and the order its cards paint in.

  Screen only. `assets/css/print.css` undoes all of it.
  """

  @doc """
  Which card a run of `count` opens on: the last, so the rest fans above it.

  Also where the stack returns on every count change, which keeps a shrinking
  run from leaving `current` pointing past its end.
  """
  @spec opens_at(pos_integer()) :: non_neg_integer()
  def opens_at(count) when is_integer(count) and count > 0, do: count - 1

  @doc """
  The z-index for the card at `index`, in a run of `count` open at `current`.

  Painted outwards from `current`, which document order cannot express, hence
  an inline style. Offset by `count` so nothing lands behind the page.

  Cards on opposite sides of `current` can tie, which is harmless only while
  `--peek` in `assets/css/stack.css` stays smaller than the gap between them.
  """
  @spec depth(non_neg_integer(), non_neg_integer(), pos_integer()) :: pos_integer()
  def depth(index, current, count) when index <= current, do: count + index
  def depth(index, current, count), do: count + 2 * current - index
end
