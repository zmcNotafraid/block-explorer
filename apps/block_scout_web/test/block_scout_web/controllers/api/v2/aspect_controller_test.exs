defmodule BlockScoutWeb.API.V2.AspectControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.Aspect.Transaction, as: AspectTransaction
  alias Explorer.Chain.Transaction
  alias Explorer.Repo

  describe "/aspect/:aspect_hash/transactions" do
    test "empty lists", %{conn: conn} do
      request = get(conn, "/api/v2/aspects/0x8f65985c1f158bff33441366ea41dd9291d9e348/transactions")
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "non empty list", %{conn: conn} do
      aspect = insert(:aspect)
      aspect_transaction = insert(:aspect_transaction, aspect_hash: aspect.hash)

      request = get(conn, "/api/v2/aspects/#{to_string(aspect.hash)}/transactions")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
    end

    test "txs with next_page_params", %{conn: conn} do
      aspect = insert(:aspect)

      txs =
        51
        |> insert_list(:aspect_transaction, aspect_hash: aspect.hash)

      request = get(conn, "/api/v2/aspects/#{to_string(aspect.hash)}/transactions")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/aspects/#{to_string(aspect.hash)}/transactions",
          response["next_page_params"]
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, txs)
    end
  end

  defp compare_item(%AspectTransaction{hash: hash} = transaction, json) do
    tx = Repo.get_by(Transaction, hash: hash)
    assert to_string(transaction.hash) == json["hash"]
    assert transaction.block_number == json["block_number"]
    assert to_string(tx.value.value) == json["value"]
    assert to_string(tx.from_address_hash) == json["from_address_hash"]
    assert to_string(tx.to_address_hash) == json["to_address_hash"]
  end

  defp check_paginated_response(first_page_resp, second_page_resp, txs) do
    assert Enum.count(first_page_resp["items"]) == 50
    assert first_page_resp["next_page_params"] != nil
    compare_item(Enum.at(txs, 50), Enum.at(first_page_resp["items"], 0))
    compare_item(Enum.at(txs, 1), Enum.at(first_page_resp["items"], 49))

    assert Enum.count(second_page_resp["items"]) == 1
    assert second_page_resp["next_page_params"] == nil
    compare_item(Enum.at(txs, 0), Enum.at(second_page_resp["items"], 0))
  end
end
