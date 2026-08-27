defmodule PaperPasswordWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also import other functionality to
  make it easier to build common data structures.

  There is no database, so every case can safely run with `async: true`.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint PaperPasswordWeb.Endpoint

      use PaperPasswordWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import PaperPasswordWeb.ConnCase
    end
  end

  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
