defmodule PaperPassword.RunTest do
  use ExUnit.Case, async: true

  alias PaperPassword.Card
  alias PaperPassword.Run

  describe "deal/2" do
    test "deals as many cards as asked for" do
      for count <- [1, 2, 4, 8] do
        assert length(Run.deal(count)) == count
      end
    end

    test "every card in a run is a different card" do
      cards = Run.deal(8)

      assert length(Enum.uniq(Enum.map(cards, & &1.id))) == 8
      assert length(Enum.uniq(Enum.map(cards, & &1.grid))) == 8
    end

    test "gives every card in the run the same alphabet" do
      cards = Run.deal(4, symbols: true)

      assert Enum.all?(cards, & &1.symbols)
      assert Enum.all?(cards, &Enum.any?(List.flatten(&1.grid), fn c -> symbol?(c) end))
    end

    test "gives every card in the run a PIN row when asked" do
      cards = Run.deal(4, pin_row: true)

      assert Enum.all?(cards, &(&1.pin_row != nil))
    end

    test "puts the PIN row somewhere different on each card" do
      rows = 20 |> Run.deal(pin_row: true) |> Enum.map(& &1.pin_row)

      assert length(Enum.uniq(rows)) > 1
    end

    test "deals plain cards by default" do
      cards = Run.deal(4)

      assert Enum.all?(cards, &(&1.symbols == false))
      assert Enum.all?(cards, &(&1.pin_row == nil))
    end

    test "refuses a run of nothing" do
      assert_raise FunctionClauseError, fn -> Run.deal(0) end
      assert_raise FunctionClauseError, fn -> Run.deal(-1) end
    end
  end

  describe "resize/3" do
    test "hands back the same run when the count has not changed" do
      cards = Run.deal(4)

      assert Run.resize(cards, 4) == cards
    end

    test "growing keeps every card already dealt, in order" do
      cards = Run.deal(2)

      grown = Run.resize(cards, 8)

      assert length(grown) == 8
      assert Enum.take(grown, 2) == cards
    end

    test "shrinking drops the tail rather than redealing" do
      cards = Run.deal(8)

      shrunk = Run.resize(cards, 2)

      assert shrunk == Enum.take(cards, 2)
    end

    test "growing back does not bring the dropped cards with it" do
      cards = Run.deal(4)

      there_and_back = cards |> Run.resize(2) |> Run.resize(4)

      assert Enum.take(there_and_back, 2) == Enum.take(cards, 2)
      assert Enum.drop(there_and_back, 2) != Enum.drop(cards, 2)
    end

    test "the cards it adds carry the alphabet it was given" do
      cards = Run.deal(1, symbols: true)

      grown = Run.resize(cards, 4, symbols: true)

      assert Enum.all?(grown, & &1.symbols)
    end

    test "a card added to a run is still a card of its own" do
      cards = Run.deal(2)

      grown = Run.resize(cards, 4)

      assert length(Enum.uniq(Enum.map(grown, & &1.id))) == 4
    end

    test "refuses to resize a run to nothing" do
      cards = Run.deal(2)

      assert_raise FunctionClauseError, fn -> Run.resize(cards, 0) end
    end
  end

  defp symbol?(char), do: char =~ ~r/^[^0-9a-zA-Z]$/

  test "a dealt card is a real card" do
    [card] = Run.deal(1)

    assert %Card{} = card
    assert {:ok, ^card} = Card.from_id(card.id)
  end
end
