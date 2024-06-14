defmodule BlockScoutWeb.API.V2.AspectController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  import BlockScoutWeb.PagingHelper, only: [delete_parameters_from_next_page_params: 1]

  alias Explorer.Chain.Aspect

  def transactions(conn, %{"aspect_hash" => aspect_hash} = params) do
    full_options = paging_options(params)

    transactions_plus_one = Aspect.list_transactions(aspect_hash, full_options)
    {transactions, next_page} = split_list_by_page(transactions_plus_one)

    next_page_params = next_page |> next_page_params(transactions, delete_parameters_from_next_page_params(params))

    conn
    |> put_status(200)
    |> render(:transactions, %{
      transactions: transactions,
      next_page_params: next_page_params
    })
  end
end
