defmodule PaperPasswordWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use PaperPasswordWeb, :html

  # Enable custom error pages
  embed_templates "error_html/*"

  # Render error messages from configured error templates.
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
