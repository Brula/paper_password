defmodule PaperPasswordWeb.FlashComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import PaperPasswordWeb.FlashComponents

  describe "connection_banners/1" do
    test "starts hidden, so nothing shows while the socket is up" do
      html = render_component(&connection_banners/1, %{})

      assert html =~ "hidden"
      refute html =~ "phx-connected={"
    end

    test "watches the body class for each way the socket can drop" do
      html = render_component(&connection_banners/1, %{})

      assert html =~ "phx-client-error #client-error"
      assert html =~ "phx-server-error #server-error"
    end

    test "hides itself again once the socket is back" do
      html = render_component(&connection_banners/1, %{})

      assert html =~ ~s(phx-connected)
      assert html =~ "#client-error"
      assert html =~ "#server-error"
    end

    test "announces itself, since a dropped socket is otherwise invisible" do
      html = render_component(&connection_banners/1, %{})

      assert length(String.split(html, ~s(role="alert"))) == 3
      assert html =~ "We can&#39;t find the internet"
      assert html =~ "Something went wrong!"
    end
  end
end
