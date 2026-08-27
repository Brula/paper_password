defmodule PaperPassword.Card.Emoji do
  @moduledoc """
  The row and column labels: animals down, objects across.

  A frozen format, like `PaperPassword.Card.Spec`. Reordering either list
  repoints every printed card's "octopus row" at different characters.

  ARCHITECTURE.md "Labels" has the curation rules these were picked against.
  """

  @type t :: %{
          required(:char) => String.t(),
          required(:name) => String.t(),
          required(:slug) => atom(),
          required(:color) => String.t(),
          optional(:tint) => String.t()
        }

  # `tint` is hand-picked, not derived from `color`: a fixed percentage of each
  # accent lands at wildly different visual weights.
  @rows_v1 [
    %{char: "🐳", name: "whale", slug: :whale, color: "#3b82f6", tint: "#dceafa"},
    %{char: "🐝", name: "bee", slug: :bee, color: "#eab308", tint: "#fbf1cd"},
    %{char: "🐙", name: "octopus", slug: :octopus, color: "#a855f7", tint: "#efe3fb"},
    %{char: "🦙", name: "llama", slug: :llama, color: "#a16207", tint: "#f3e5d3"},
    %{char: "🐧", name: "penguin", slug: :penguin, color: "#334155", tint: "#e3e8ef"},
    %{char: "🐷", name: "pig", slug: :pig, color: "#ec4899", tint: "#fbe0ed"},
    %{char: "🐢", name: "turtle", slug: :turtle, color: "#22c55e", tint: "#ddf4e3"},
    %{char: "🐘", name: "elephant", slug: :elephant, color: "#94a3b8", tint: "#eceef0"}
  ]

  @columns_v1 [
    %{char: "🍕", name: "pizza", slug: :pizza, color: "#f97316"},
    %{char: "🌵", name: "cactus", slug: :cactus, color: "#16a34a"},
    %{char: "🎸", name: "guitar", slug: :guitar, color: "#a16207"},
    %{char: "🔑", name: "key", slug: :key, color: "#eab308"},
    %{char: "🍄", name: "mushroom", slug: :mushroom, color: "#dc2626"},
    %{char: "⚡", name: "lightning", slug: :lightning, color: "#eab308"},
    %{char: "🚀", name: "rocket", slug: :rocket, color: "#64748b"},
    %{char: "🍌", name: "banana", slug: :banana, color: "#facc15"},
    %{char: "🌻", name: "sunflower", slug: :sunflower, color: "#f59e0b"},
    %{char: "🎩", name: "top hat", slug: :top_hat, color: "#1e293b"},
    %{char: "🌲", name: "tree", slug: :tree, color: "#15803d"},
    %{char: "🍆", name: "eggplant", slug: :eggplant, color: "#7c3aed"},
    %{char: "⌛", name: "hourglass", slug: :hourglass, color: "#d97706"},
    %{char: "🔥", name: "fire", slug: :fire, color: "#ea580c"},
    %{char: "🍺", name: "beer", slug: :beer, color: "#f59e0b"},
    %{char: "🌊", name: "wave", slug: :wave, color: "#0284c7"},
    %{char: "💡", name: "light bulb", slug: :light_bulb, color: "#fbbf24"},
    %{char: "🌈", name: "rainbow", slug: :rainbow, color: "#8b5cf6"},
    %{char: "🎉", name: "party popper", slug: :party_popper, color: "#ca8a04"},
    %{char: "⭐", name: "star", slug: :star, color: "#facc15"},
    %{char: "🍀", name: "clover", slug: :clover, color: "#16a34a"}
  ]

  @doc "The row and column labels for `version`, or `:error` if it is unknown."
  @spec fetch(pos_integer()) :: {:ok, %{rows: [t()], columns: [t()]}} | :error
  def fetch(1), do: {:ok, %{rows: @rows_v1, columns: @columns_v1}}
  def fetch(_other), do: :error
end
