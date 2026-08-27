defmodule PaperPassword.Run do
  @moduledoc """
  A run of cards: whatever happens to be on the page together.

  Only a list: every card has its own seed and ID, and nothing records that
  they were printed as a set. These are the two ways the list may change.
  """

  alias PaperPassword.Card

  @doc """
  Deals `count` fresh cards, each with its own seed.

  `opts` go to every card, so a run shares one alphabet.
  """
  @spec deal(pos_integer(), keyword()) :: [Card.t()]
  def deal(count, opts \\ []) when is_integer(count) and count > 0 do
    Enum.map(1..count//1, fn _ -> Card.new(opts) end)
  end

  @doc """
  Grows or shrinks `cards` to `count`, from the end, leaving the rest alone.

  Dropped cards are gone: 4 -> 2 -> 4 gives back two cards that are not the two
  that went.
  """
  @spec resize([Card.t()], pos_integer(), keyword()) :: [Card.t()]
  def resize(cards, count, opts \\ []) when is_integer(count) and count > 0 do
    case count - length(cards) do
      0 -> cards
      short when short > 0 -> cards ++ deal(short, opts)
      _over -> Enum.take(cards, count)
    end
  end
end
