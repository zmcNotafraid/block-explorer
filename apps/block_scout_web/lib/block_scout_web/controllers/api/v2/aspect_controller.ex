defmodule BlockScoutWeb.API.V2.AspectController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  import BlockScoutWeb.PagingHelper, only: [delete_parameters_from_next_page_params: 1]

  alias Explorer.Chain.Aspect
  alias Explorer.Chain

  @aspect_options [
    necessity_by_association: %{
      :versions => :optional
    },
    api?: true
  ]

  @api_true [api?: true]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

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

  def bound_addresses(conn, %{"aspect_hash" => aspect_hash} = params) do
    full_options = paging_options(params)

    bound_addresses_plus_one = Aspect.list_bound_addresses(aspect_hash, full_options)
    {bound_addresses, next_page} = split_list_by_page(bound_addresses_plus_one)

    next_page_params = next_page |> next_page_params(bound_addresses, delete_parameters_from_next_page_params(params))

    conn
    |> put_status(200)
    |> render(:bound_addresses, %{
      bound_addresses: bound_addresses,
      next_page_params: next_page_params
    })
  end

  def aspect(conn, %{"aspect_hash_param" => aspect_hash_string} = params) do
    with {:ok, _aspect_hash, aspect} <- validate_aspect(aspect_hash_string, params, @aspect_options) do
      conn
      |> put_status(200)
      |> render(:aspect, %{aspect: aspect})
    end
  end

  def validate_aspect(aspect_hash_string, params, options \\ @api_true) do
    with {:format, {:ok, aspect_hash}} <- {:format, Chain.string_to_address_hash(aspect_hash_string)},
         {:not_found, {:ok, aspect}} <- {:not_found, Aspect.hash_to_aspect(aspect_hash, options)} do
      {:ok, aspect_hash, aspect}
    end
  end
end
