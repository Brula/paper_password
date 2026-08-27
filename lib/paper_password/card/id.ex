defmodule PaperPassword.Card.Id do
  @moduledoc """
  Card IDs, in [Crockford base32](https://www.crockford.com/base32.html) with a
  check symbol.

      V1-ABCD-EFGH-1234-56789
      ^  ^                  ^
      |  payload (80 bits)  check symbol
      spec version

  Without the check symbol a typo would decode to a *different valid card*.
  """

  alias PaperPassword.Card.Spec

  @seed_bytes 10
  @seed_bits @seed_bytes * 8
  @payload_length div(@seed_bits, 5)
  @body_length @payload_length + 1

  @separator ~r/[\s-]+/

  @crockford ~c"0123456789ABCDEFGHJKMNPQRSTVWXYZ"
  @check_symbols ~c"0123456789ABCDEFGHJKMNPQRSTVWXYZ*~$=U"

  @type seed :: binary()
  @type error :: :bad_format | :bad_checksum | :unknown_version

  @doc "A fresh random #{@seed_bytes}-byte seed."
  @spec random_seed() :: seed()
  def random_seed, do: :crypto.strong_rand_bytes(@seed_bytes)

  @doc "Encodes a #{@seed_bytes}-byte seed and spec version into a card ID."
  @spec encode(seed(), pos_integer()) :: String.t()
  def encode(seed, version \\ 1) when byte_size(seed) == @seed_bytes do
    payload = for <<chunk::5 <- seed>>, into: "", do: <<Enum.at(@crockford, chunk)>>
    check = <<Enum.at(@check_symbols, check_value(seed))>>

    "V#{version}-" <> group(payload <> check)
  end

  @doc """
  Decodes a card ID back into its spec and seed.

  Case, separators and surrounding whitespace are ignored, and the Crockford
  confusables `I`/`L` and `O` fold onto `1` and `0`.
  """
  @spec decode(String.t()) :: {:ok, Spec.t(), seed()} | {:error, error()}
  def decode(id) when is_binary(id) do
    with {:ok, version, body} <- split(id),
         {:ok, spec} <- fetch_spec(version),
         {:ok, seed} <- decode_body(body) do
      {:ok, spec, seed}
    end
  end

  # Every separator is optional, the one after the version prefix included.
  defp split(id) do
    case String.trim(id) do
      <<v, rest::binary>> when v in [?V, ?v] -> split_version(rest)
      _ -> {:error, :bad_format}
    end
  end

  # Without that separator the prefix is ambiguous: `V15N54…` is version 1 of a
  # body starting `5N54` as readily as version 15 of one starting `N54`. Fall
  # back to the body's fixed length, which also catches a missing first hyphen.
  defp split_version(rest) do
    with [version, body] <- String.split(rest, @separator, parts: 2),
         {:ok, version, body} <- parse_version(version, body) do
      {:ok, version, body}
    else
      _ ->
        rest
        |> String.replace(@separator, "")
        |> String.split_at(-@body_length)
        |> parse_version()
    end
  end

  defp parse_version({version, body}), do: parse_version(version, body)

  defp parse_version(version, body) do
    case Integer.parse(version) do
      {version, ""} when version > 0 -> {:ok, version, body}
      _ -> {:error, :bad_format}
    end
  end

  defp fetch_spec(version) do
    case Spec.fetch(version) do
      {:ok, spec} -> {:ok, spec}
      :error -> {:error, :unknown_version}
    end
  end

  defp decode_body(body) do
    normalized = normalize(body)

    with <<payload::binary-size(@payload_length), check::binary-1>> <- normalized,
         {:ok, seed} <- decode_payload(payload) do
      if check == <<Enum.at(@check_symbols, check_value(seed))>> do
        {:ok, seed}
      else
        {:error, :bad_checksum}
      end
    else
      _ -> {:error, :bad_format}
    end
  end

  defp decode_payload(payload) do
    Enum.reduce_while(String.to_charlist(payload), {:ok, <<>>}, fn char, {:ok, acc} ->
      case Enum.find_index(@crockford, &(&1 == char)) do
        nil -> {:halt, {:error, :bad_format}}
        index -> {:cont, {:ok, <<acc::bitstring, index::5>>}}
      end
    end)
  end

  defp normalize(body) do
    body
    |> String.upcase()
    |> String.replace(["-", " "], "")
    |> String.replace(["I", "L"], "1")
    |> String.replace("O", "0")
  end

  defp check_value(seed) do
    <<value::size(@seed_bits)>> = seed
    rem(value, length(@check_symbols))
  end

  defp group(string) do
    string
    |> String.graphemes()
    |> Enum.chunk_every(4)
    |> Enum.map(&Enum.join/1)
    |> join_trailing_check()
  end

  defp join_trailing_check(groups) do
    case Enum.split(groups, -2) do
      {leading, [last, <<check::binary-1>>]} -> Enum.join(leading ++ [last <> check], "-")
      _ -> Enum.join(groups, "-")
    end
  end
end
