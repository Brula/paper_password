defmodule PaperPasswordWeb.CompassTest do
  use ExUnit.Case, async: true

  alias PaperPasswordWeb.Compass

  describe "keys/1" do
    test "offers eight keys, each an arrow, a name and a reading" do
      for format <- [:print, :phone] do
        keys = Compass.keys(format)

        assert length(keys) == 8
        assert Enum.all?(keys, fn {arrow, name, _} -> arrow != "" and name != "" end)
      end
    end

    test "names every reading exactly once, in both formats" do
      for format <- [:print, :phone] do
        readings = for {_arrow, _name, reading} <- Compass.keys(format), do: reading

        assert length(Enum.uniq(readings)) == 8
      end
    end

    test "the arrows and their names are the same keys in both formats" do
      labels = fn format -> for {arrow, name, _} <- Compass.keys(format), do: {arrow, name} end

      assert labels.(:print) == labels.(:phone)
    end

    test "the wallet card reads the way the arrows point" do
      assert reading(:print, "→") == :right
      assert reading(:print, "↓") == :down
      assert reading(:print, "←") == :left
      assert reading(:print, "↑") == :up
    end

    test "the phone card is the wallet card reflected about its main diagonal" do
      assert reading(:phone, "→") == :down
      assert reading(:phone, "↓") == :right
      assert reading(:phone, "←") == :up
      assert reading(:phone, "↑") == :left
    end

    test "the two keys on the axis of reflection come through unchanged" do
      assert reading(:print, "↖") == reading(:phone, "↖")
      assert reading(:print, "↘") == reading(:phone, "↘")
    end

    test "the other two diagonals swap" do
      assert reading(:print, "↗") == :up_right
      assert reading(:phone, "↗") == :down_left
      assert reading(:print, "↙") == :down_left
      assert reading(:phone, "↙") == :up_right
    end

    test "opposite keys are four apart, so the compass turns steadily" do
      arrows = for {arrow, _name, _} <- Compass.keys(:print), do: arrow

      assert arrows == ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
    end
  end

  describe "fetch/1" do
    test "accepts every reading the compass offers, in either format" do
      for format <- [:print, :phone], {_arrow, _name, reading} <- Compass.keys(format) do
        assert Compass.fetch(Atom.to_string(reading)) == {:ok, reading}
      end
    end

    test "rejects an atom this node has loaded but the compass never offered" do
      # `String.to_existing_atom/1` would hand this straight back.
      assert Compass.fetch("erlang") == :error
      assert Compass.fetch("nil") == :error
    end

    test "rejects anything that isn't a direction at all" do
      for claim <- ["", "sideways", "RIGHT", "down_rightish", "1"] do
        assert Compass.fetch(claim) == :error
      end
    end
  end

  defp reading(format, arrow) do
    {^arrow, _name, reading} = Enum.find(Compass.keys(format), &(elem(&1, 0) == arrow))
    reading
  end
end
