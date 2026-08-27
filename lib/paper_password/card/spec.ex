defmodule PaperPassword.Card.Spec do
  @moduledoc """
  The frozen description of a card layout.

  Once cards have been printed against a version, that version must keep
  generating byte-identical grids forever. Never edit `v1/0`; add `v2/0`.
  """

  @enforce_keys [
    :version,
    :rows,
    :cols,
    :alphabet,
    :symbol_alphabet,
    :digit_alphabet
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          version: pos_integer(),
          rows: pos_integer(),
          cols: pos_integer(),
          alphabet: tuple(),
          symbol_alphabet: tuple(),
          digit_alphabet: tuple()
        }

  # Frozen. Confusables included; the mono font disambiguates them at render
  # time.
  @alphabet ~c"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

  # Frozen. The same with or without symbols: a PIN pad has ten keys.
  @digits ~c"0123456789"

  # Frozen. Curated for legibility at 3.5mm; see ARCHITECTURE.md "Alphabets".
  @symbols ~c"!#$%&*+=?@^;<>()"

  @doc """
  Version 1: eight rows of 21 characters.

  21 must stay coprime with 8 or `read/5`'s diagonals stop touring the grid.
  """
  @spec v1() :: t()
  def v1 do
    %__MODULE__{
      version: 1,
      rows: 8,
      cols: 21,
      alphabet: List.to_tuple(Enum.map(@alphabet, &<<&1>>)),
      symbol_alphabet: List.to_tuple(Enum.map(@alphabet ++ @symbols, &<<&1>>)),
      digit_alphabet: List.to_tuple(Enum.map(@digits, &<<&1>>))
    }
  end

  @doc "Returns the spec for `version`, or `:error` if it is unknown."
  @spec fetch(pos_integer()) :: {:ok, t()} | :error
  def fetch(1), do: {:ok, v1()}
  def fetch(_other), do: :error

  @doc """
  Whether `seed` describes a card with symbols in it.

  Carried by the seed's top bit rather than a flag on the ID, so the check
  symbol covers it and a mistyped flag reads as a typo. `pin_row?/1` has the
  bit next to it.
  """
  @spec symbols?(binary()) :: boolean()
  def symbols?(<<1::1, _rest::bitstring>>), do: true
  def symbols?(<<0::1, _rest::bitstring>>), do: false

  @doc "Returns `seed` with its symbols bit set to `symbols?`."
  @spec with_symbols(binary(), boolean()) :: binary()
  def with_symbols(<<_flag::1, rest::bitstring>>, symbols?) do
    flag = if symbols?, do: 1, else: 0
    <<flag::1, rest::bitstring>>
  end

  @doc """
  Whether `seed` describes a card with a digits-only row on it.

  In the seed for the same reason as `symbols?/1`. Which row it lands on comes
  off the keystream, so it differs per card.
  """
  @spec pin_row?(binary()) :: boolean()
  def pin_row?(<<_symbols::1, 1::1, _rest::bitstring>>), do: true
  def pin_row?(<<_symbols::1, 0::1, _rest::bitstring>>), do: false

  @doc "Returns `seed` with its PIN row bit set to `pin_row?`."
  @spec with_pin_row(binary(), boolean()) :: binary()
  def with_pin_row(<<symbols::1, _flag::1, rest::bitstring>>, pin_row?) do
    flag = if pin_row?, do: 1, else: 0
    <<symbols::1, flag::1, rest::bitstring>>
  end

  @doc "The alphabet a card with or without symbols draws its cells from."
  @spec alphabet_for(t(), boolean()) :: tuple()
  def alphabet_for(%__MODULE__{} = spec, true), do: spec.symbol_alphabet
  def alphabet_for(%__MODULE__{} = spec, false), do: spec.alphabet
end
