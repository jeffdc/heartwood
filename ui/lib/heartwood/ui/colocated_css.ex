defmodule Heartwood.UI.ColocatedCSS do
  @moduledoc """
  The `:type` of heartwood's colocated `<style>` blocks: global CSS,
  extracted as it is into `phoenix-colocated/heartwood_ui/colocated.css`,
  which an app imports. Each component's CSS scopes itself, with its own
  class prefix, in `@layer components`.
  """
  use Phoenix.LiveView.ColocatedCSS

  @impl true
  def transform("style", _attrs, css, _meta), do: {:ok, css, []}
end
