defmodule PaperPasswordWeb.StackTest do
  use ExUnit.Case, async: true

  alias PaperPasswordWeb.Stack

  # Every run size the UI offers, at every card it can open at.
  @runs for count <- [1, 2, 4, 8], current <- 0..(count - 1), do: {count, current}

  describe "opens_at/1" do
    test "opens a run on its last card" do
      assert Stack.opens_at(1) == 0
      assert Stack.opens_at(4) == 3
      assert Stack.opens_at(8) == 7
    end

    test "always names a card that is actually in the run" do
      for count <- [1, 2, 4, 8] do
        assert Stack.opens_at(count) in 0..(count - 1)
      end
    end

    test "refuses a run of nothing" do
      assert_raise FunctionClauseError, fn -> Stack.opens_at(0) end
    end
  end

  describe "depth/3" do
    test "puts the open card in front of every other card in the run" do
      for {count, current} <- @runs, index <- 0..(count - 1), index != current do
        assert Stack.depth(index, current, count) < Stack.depth(current, current, count),
               "card #{index} was not behind the open card #{current} in a run of #{count}"
      end
    end

    test "never paints a card behind the page" do
      # A negative z-index is behind the body, not behind the card in front.
      for {count, current} <- @runs, index <- 0..(count - 1) do
        assert Stack.depth(index, current, count) > 0
      end
    end

    test "cards above the open one climb towards it" do
      for {count, current} <- @runs, current > 0, index <- 0..(current - 1) do
        assert Stack.depth(index, current, count) < Stack.depth(index + 1, current, count)
      end
    end

    test "cards below the open one fall away from it" do
      for {count, current} <- @runs, index <- current..(count - 2)//1, count > 1 do
        assert Stack.depth(index, current, count) > Stack.depth(index + 1, current, count)
      end
    end

    test "neighbouring slots never tie, so document order never decides" do
      # Adjacent slots are the ones that overlap; a tie leaves the lapping to
      # document order.
      for {count, current} <- @runs, index <- 0..(count - 2)//1 do
        refute Stack.depth(index, current, count) == Stack.depth(index + 1, current, count)
      end
    end

    test "two cards on the same side of the open one never tie" do
      for {count, current} <- @runs do
        above = for i <- 0..current, do: Stack.depth(i, current, count)
        below = for i <- current..(count - 1), do: Stack.depth(i, current, count)

        assert length(Enum.uniq(above)) == length(above)
        assert length(Enum.uniq(below)) == length(below)
      end
    end

    test "a run of one is a single card at the front" do
      assert Stack.depth(0, 0, 1) == 1
    end

    test "the whole run is painted, whichever card it is open at" do
      for {count, current} <- @runs do
        depths = for i <- 0..(count - 1), do: Stack.depth(i, current, count)

        assert length(depths) == count
        assert Enum.all?(depths, &is_integer/1)
      end
    end
  end
end
