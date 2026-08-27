defmodule PaperPasswordWeb.ErrorHTMLTest do
  use PaperPasswordWeb.ConnCase, async: true

  import Phoenix.Template

  test "renders 404.html" do
    html = render_to_string(PaperPasswordWeb.ErrorHTML, "404", "html", [])
    assert html =~ "Page Not Found"
    assert html =~ ">404<"
  end

  test "renders 500.html" do
    html = render_to_string(PaperPasswordWeb.ErrorHTML, "500", "html", [])
    assert html =~ "Something Went Wrong"
    assert html =~ ">500<"
  end
end
