defmodule BlockScoutWeb.API.V2.AspectControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.Aspect.Transaction, as: AspectTransaction
  alias Explorer.Chain.Aspect.Version, as: AspectVersion
  alias Explorer.Chain.Aspect.BoundAddress
  alias Explorer.Chain.{Aspect, Transaction}
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
      insert(:aspect_transaction, aspect_hash: aspect.hash)

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

  describe "/aspect/:aspect_hash/bound_addresses" do
    test "empty lists", %{conn: conn} do
      request = get(conn, "/api/v2/aspects/0x8f65985c1f158bff33441366ea41dd9291d9e348/bound_addresses")
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "non empty list", %{conn: conn} do
      bound_address = insert(:aspect_bound_address)

      request = get(conn, "/api/v2/aspects/#{to_string(bound_address.aspect_hash)}/bound_addresses")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
    end

    test "bound_addresses with next_page_params", %{conn: conn} do
      aspect = insert(:aspect)

      txs =
        51
        |> insert_list(:aspect_bound_address, aspect_hash: aspect.hash)

      request = get(conn, "/api/v2/aspects/#{to_string(aspect.hash)}/bound_addresses")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/aspects/#{to_string(aspect.hash)}/bound_addresses",
          response["next_page_params"]
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, txs)
    end
  end

  describe "/aspect/:aspect_hash" do
    test "not found", %{conn: conn} do
      request = get(conn, "/api/v2/aspects/0x8f65985c1f158bff33441366ea41dd9291d9e348")
      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "returns aspect with version", %{conn: conn} do
      aspect = insert(:aspect, version: 1)
      versions = insert_list(2, :aspect_version, aspect_hash: aspect.hash)
      insert(:aspect_bound_address, aspect_hash: aspect.hash)

      request = get(conn, "/api/v2/aspects/#{aspect.hash}")
      aspect_hash = to_string(aspect.hash)
      response = json_response(request, 200)
      deployed_tx = versions |> List.last() |> Map.get(:aspect_transaction_hash) |> to_string()

      compare_item(versions |> List.last(), response["versions"] |> List.last())
      compare_item(versions |> List.first(), response["versions"] |> List.first())

      assert %{
               "bound_address_count" => 1,
               "deployed_tx" => ^deployed_tx,
               "hash" => ^aspect_hash,
               "join_points" => ["pre_tx_execute"],
               "properties" => nil
             } = response
    end
  end

  defp compare_item(%AspectVersion{} = version, json) do
    assert to_string(version.aspect_transaction_hash) == json["aspect_transaction_hash"]
    assert version.block_number == json["block_number"]
    assert version.aspect_transaction_index == json["aspect_transaction_index"]
    assert Aspect.decode_join_points(version.join_points) == json["join_points"]
    assert version.properties == json["properties"]
    assert version.version == json["version"]
  end

  defp compare_item(%AspectTransaction{hash: hash} = transaction, json) do
    tx = Repo.get_by(Transaction, hash: hash)
    assert to_string(transaction.hash) == json["hash"]
    assert transaction.block_number == json["block_number"]
    assert to_string(tx.value.value) == json["value"]
    assert to_string(tx.from_address_hash) == json["from_address_hash"]
    assert to_string(tx.to_address_hash) == json["to_address_hash"]
  end

  defp compare_item(%BoundAddress{aspect_hash: aspect_hash} = bound_address, json) do
    assert to_string(bound_address.bound_address_hash) == json["bound_address_hash"]
    assert bound_address.bind_block_number == json["bind_block_number"]
    assert bound_address.bind_aspect_transaction_index == json["bind_aspect_transaction_index"]
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
