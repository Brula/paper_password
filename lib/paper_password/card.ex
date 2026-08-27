defmodule PaperPassword.Card do
  @moduledoc """
  Deterministic generation of password cards. The same ID always produces the
  same grid, and nothing about a card is stored.

  See ARCHITECTURE.md for why the keystream is ChaCha20 and why cells are drawn
  by rejection sampling.
  """

  alias PaperPassword.Card.Emoji
  alias PaperPassword.Card.Id
  alias PaperPassword.Card.Spec

  @enforce_keys [:id, :spec, :grid, :row_labels, :col_labels, :symbols, :pin_row]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          spec: Spec.t(),
          grid: [[String.t()]],
          row_labels: [Emoji.t()],
          col_labels: [Emoji.t()],
          symbols: boolean(),
          pin_row: non_neg_integer() | nil
        }

  @block_size 64
  @zero_block :binary.copy(<<0>>, @block_size)

  @doc """
  Builds a brand new card from a freshly generated random seed.

    * `:symbols` draws every cell from the alphabet with punctuation in it.
    * `:pin_row` gives one row over to digits, for PINs.

  Both travel in the seed, so they are fixed here rather than at render time.
  See `Spec.symbols?/1`.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    spec = Spec.v1()

    seed =
      Id.random_seed()
      |> Spec.with_symbols(Keyword.get(opts, :symbols, false))
      |> Spec.with_pin_row(Keyword.get(opts, :pin_row, false))

    build(Id.encode(seed, spec.version), spec, seed)
  end

  @doc """
  Rebuilds the card identified by `id`.
  """
  @spec from_id(String.t()) :: {:ok, t()} | {:error, Id.error()}
  def from_id(id) when is_binary(id) do
    with {:ok, spec, seed} <- Id.decode(id) do
      {:ok, build(Id.encode(seed, spec.version), spec, seed)}
    end
  end

  defp build(id, spec, seed) do
    {:ok, labels} = Emoji.fetch(spec.version)
    {grid, pin_row} = layout(spec, seed)

    %__MODULE__{
      id: id,
      spec: spec,
      grid: grid,
      row_labels: labels.rows,
      col_labels: labels.columns,
      symbols: Spec.symbols?(seed),
      pin_row: pin_row
    }
  end

  defp layout(spec, seed) do
    alphabet = Spec.alphabet_for(spec, Spec.symbols?(seed))
    {pin_row, source} = pin_row(spec, seed, keystream(spec, seed))

    {rows, _source} =
      Enum.map_reduce(0..(spec.rows - 1), source, fn row_index, source ->
        row_alphabet = if row_index == pin_row, do: spec.digit_alphabet, else: alphabet
        take_row(row_alphabet, spec.cols, source)
      end)

    {rows, pin_row}
  end

  # Off the front of the keystream, so a reprint puts the digits back on the
  # same row.
  defp pin_row(spec, seed, source) do
    if Spec.pin_row?(seed) do
      take_uniform(List.to_tuple(Enum.to_list(0..(spec.rows - 1))), source)
    else
      {nil, source}
    end
  end

  defp take_row(alphabet, cols, source) do
    Enum.map_reduce(1..cols, source, fn _col, source -> take_uniform(alphabet, source) end)
  end

  # Rejection sampling: bytes in the incomplete final window of 0..255 are
  # discarded rather than folded, which would bias the alphabet's opening.
  defp take_uniform(choices, source) do
    size = tuple_size(choices)
    limit = 256 - rem(256, size)
    {byte, source} = next_byte(source)

    if byte < limit do
      {elem(choices, rem(byte, size)), source}
    else
      take_uniform(choices, source)
    end
  end

  # OTP's `:chacha20` wants a 16-byte IV of `counter || nonce` with the counter
  # little-endian. The domain separator stops a future spec version reusing this
  # one's keystream for the same seed.
  defp keystream(spec, seed) do
    <<key::binary-32, nonce::binary-12, _rest::binary>> =
      :crypto.hash(:sha512, ["paper_password/grid/v", Integer.to_string(spec.version), "/", seed])

    {[], 0, key, nonce}
  end

  defp next_byte({[byte | rest], counter, key, nonce}), do: {byte, {rest, counter, key, nonce}}

  defp next_byte({[], counter, key, nonce}) do
    iv = <<counter::little-32, nonce::binary>>
    block = :crypto.crypto_one_time(:chacha20, key, iv, @zero_block, true)
    next_byte({:binary.bin_to_list(block), counter + 1, key, nonce})
  end

  @doc """
  Finds the zero-based cell named by a row and column emoji.

  This is how a person actually addresses a cell ("the octopus row, the guitar
  column"), so it takes the two slugs rather than coordinates.
  """
  @spec locate(t(), atom(), atom()) :: {:ok, {non_neg_integer(), non_neg_integer()}} | :error
  def locate(%__MODULE__{} = card, row_slug, col_slug) do
    row = Enum.find_index(card.row_labels, &(&1.slug == row_slug))
    col = Enum.find_index(card.col_labels, &(&1.slug == col_slug))

    if row && col, do: {:ok, {row, col}}, else: :error
  end

  @type direction ::
          :right
          | :left
          | :down
          | :up
          | :down_right
          | :down_left
          | :up_right
          | :up_left

  @type coordinate :: {non_neg_integer(), non_neg_integer()}

  @doc """
  Reads `length` characters starting at `{row, col}` (both zero-based).

  Reading never runs off the edge: `:right` and `:left` continue on the
  neighbouring row, `:down` and `:up` on the neighbouring column, and the four
  diagonals walk the grid as a torus. All eight tour every cell before
  repeating.
  """
  @spec read(t(), non_neg_integer(), non_neg_integer(), pos_integer(), direction()) :: String.t()
  def read(%__MODULE__{} = card, row, col, length, direction \\ :right) do
    card
    |> trail(row, col, length, direction)
    |> Enum.map_join(&cell(card, &1))
  end

  @doc """
  The cells `read/5` visits, in order.

  Both come from here, so a highlight cannot disagree with the password under
  it.
  """
  @spec trail(t(), non_neg_integer(), non_neg_integer(), pos_integer(), direction()) ::
          [coordinate()]
  def trail(%__MODULE__{spec: spec}, row, col, length, direction \\ :right) do
    Enum.map(0..(length - 1), &position(direction, spec, row, col, &1))
  end

  # Reverses cost nothing because `Integer.mod/2` floors: a negative offset
  # wraps off the front of the grid the way a positive one wraps off the end.
  defp position(:right, spec, row, col, offset), do: along_rows(spec, row, col, offset)
  defp position(:left, spec, row, col, offset), do: along_rows(spec, row, col, -offset)

  defp position(:down, spec, row, col, offset), do: along_cols(spec, row, col, offset)
  defp position(:up, spec, row, col, offset), do: along_cols(spec, row, col, -offset)

  defp position(:down_right, spec, row, col, offset), do: diagonal(spec, row, col, offset, offset)
  defp position(:down_left, spec, row, col, offset), do: diagonal(spec, row, col, offset, -offset)
  defp position(:up_right, spec, row, col, offset), do: diagonal(spec, row, col, -offset, offset)
  defp position(:up_left, spec, row, col, offset), do: diagonal(spec, row, col, -offset, -offset)

  defp along_rows(spec, row, col, step) do
    index = Integer.mod(row * spec.cols + col + step, spec.rows * spec.cols)
    {div(index, spec.cols), rem(index, spec.cols)}
  end

  defp along_cols(spec, row, col, step) do
    index = Integer.mod(col * spec.rows + row + step, spec.rows * spec.cols)
    {rem(index, spec.rows), div(index, spec.rows)}
  end

  # Only tours the whole grid while `rows` and `cols` stay coprime. Break that
  # and a diagonal password repeats early; nothing else notices.
  defp diagonal(spec, row, col, row_step, col_step) do
    {Integer.mod(row + row_step, spec.rows), Integer.mod(col + col_step, spec.cols)}
  end

  defp cell(%__MODULE__{grid: grid}, {row, col}) do
    grid |> Enum.at(row) |> Enum.at(col)
  end
end
