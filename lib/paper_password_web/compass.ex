defmodule PaperPasswordWeb.Compass do
  @moduledoc """
  The eight reading directions, as the keys that name them.

  An arrow belongs to the key, which never moves; which reading it names depends
  on the format. The phone card is the grid reflected about its main diagonal,
  so its compass is too. ↖ and ↘ are the two that survive unchanged.
  """

  alias PaperPassword.Card

  @typedoc "An arrow, its accessible name, and the reading it names in one format."
  @type key :: {String.t(), String.t(), Card.direction()}

  # {arrow, name, wallet reading, phone reading}
  @keys [
    {"→", "right", :right, :down},
    {"↘", "down and right", :down_right, :down_right},
    {"↓", "down", :down, :right},
    {"↙", "down and left", :down_left, :up_right},
    {"←", "left", :left, :up},
    {"↖", "up and left", :up_left, :up_left},
    {"↑", "up", :up, :left},
    {"↗", "up and right", :up_right, :down_left}
  ]

  @directions for {_arrow, _name, direction, _phone} <- @keys, do: direction

  @doc """
  The compass with each key resolved to the reading it names in `format`.
  """
  @spec keys(:print | :phone) :: [key()]
  def keys(:phone), do: for({arrow, name, _wallet, phone} <- @keys, do: {arrow, name, phone})
  def keys(:print), do: for({arrow, name, wallet, _phone} <- @keys, do: {arrow, name, wallet})

  @doc """
  Resolves a direction that arrived over the socket.

  Checked against the compass, not `String.to_existing_atom/1`, which would
  admit any atom this node has loaded.
  """
  @spec fetch(String.t()) :: {:ok, Card.direction()} | :error
  def fetch(direction) when is_binary(direction) do
    case Enum.find(@directions, &(Atom.to_string(&1) == direction)) do
      nil -> :error
      found -> {:ok, found}
    end
  end
end
