defmodule MissionspaceWeb.PaginationHelpers do
  @doc """
  Builds pagination options from request parameters.
  """
  def build_pagination_opts(params) do
    opts = []

    opts =
      if params["limit"], do: [{:limit, String.to_integer(params["limit"])} | opts], else: opts

    opts = if params["after"], do: [{:after, params["after"]} | opts], else: opts
    opts = if params["before"], do: [{:before, params["before"]} | opts], else: opts

    opts
  end

  @doc """
  Renders paginated response with metadata.
  """
  def render_page(page, data_fn) do
    %{
      data: for(item <- page.entries, do: data_fn.(item)),
      metadata: %{
        after: page.metadata.after,
        before: page.metadata.before,
        limit: page.metadata.limit
      }
    }
  end
end
