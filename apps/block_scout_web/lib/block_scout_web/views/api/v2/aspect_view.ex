defmodule BlockScoutWeb.API.V2.AspectView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.{ApiView, Helper}

  alias Explorer.Chain.Transaction
  alias Explorer.Chain.Aspect.Transaction, as: AspectTransaction

  def render("message.json", assigns) do
    ApiView.render("message.json", assigns)
  end

  def render("transactions.json", %{transactions: transactions, next_page_params: next_page_params, conn: conn}) do
    %{
      "items" =>
        transactions
        |> Enum.map(fn tx ->
          tx
          |> Map.merge(%{
            fee: %Transaction{gas_price: tx.gas_price, gas_used: tx.gas_used} |> Transaction.fee(:wei) |> format_fee()
          })
        end),
      "next_page_params" => next_page_params
    }
  end

  def format_fee({type, value}), do: %{"type" => type, "value" => value}
end
