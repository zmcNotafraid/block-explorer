defmodule Indexer.Transform.Aspects do
  @moduledoc """
  Helper functions for transforming input data for aspect transactions.
  """

  import Bitwise

  require Logger

  alias Explorer.Chain.Aspect

  @operation_function_signature "995a75e8"
  @deploy_function_signature "ef00b7b0"
  @deploy_function_abi [
    %{
      "inputs" => [
        %{"internalType" => "bytes", "name" => "code", "type" => "bytes"},
        %{
          "components" => [
            %{"internalType" => "string", "name" => "key", "type" => "string"},
            %{"internalType" => "bytes", "name" => "value", "type" => "bytes"}
          ],
          "internalType" => "struct AspectCore.KVPair[]",
          "name" => "properties",
          "type" => "tuple[]"
        },
        %{"internalType" => "address", "name" => "account", "type" => "address"},
        %{"internalType" => "bytes", "name" => "proof", "type" => "bytes"},
        %{
          "internalType" => "uint256",
          "name" => "joinPoints",
          "type" => "uint256"
        }
      ],
      "name" => "deploy",
      "outputs" => [],
      "stateMutability" => "nonpayable",
      "type" => "function"
    }
  ]

  @bind_function_signature "3446f1d2"
  @bind_function_abi [
    %{
      "inputs" => [
        %{"internalType" => "address", "name" => "aspectId", "type" => "address"},
        %{
          "internalType" => "uint256",
          "name" => "aspectVersion",
          "type" => "uint256"
        },
        %{
          "internalType" => "address",
          "name" => "accountAddr",
          "type" => "address"
        },
        %{"internalType" => "int8", "name" => "priority", "type" => "int8"}
      ],
      "name" => "bind",
      "outputs" => [],
      "stateMutability" => "nonpayable",
      "type" => "function"
    }
  ]

  @unbind_function_signature "4930308e"
  @unbind_function_abi [
    %{
      "inputs" => [
        %{"internalType" => "address", "name" => "aspectId", "type" => "address"},
        %{
          "internalType" => "address",
          "name" => "accountAddr",
          "type" => "address"
        }
      ],
      "name" => "unbind",
      "outputs" => [],
      "stateMutability" => "nonpayable",
      "type" => "function"
    }
  ]
  @upgrade_function_signature "100a252e"
  @upgrade_function_abi [
    %{
      "inputs" => [
        %{"internalType" => "address", "name" => "aspectId", "type" => "address"},
        %{"internalType" => "bytes", "name" => "code", "type" => "bytes"},
        %{
          "components" => [
            %{"internalType" => "string", "name" => "key", "type" => "string"},
            %{"internalType" => "bytes", "name" => "value", "type" => "bytes"}
          ],
          "internalType" => "struct AspectCore.KVPair[]",
          "name" => "properties",
          "type" => "tuple[]"
        },
        %{
          "internalType" => "uint256",
          "name" => "joinPoints",
          "type" => "uint256"
        }
      ],
      "name" => "upgrade",
      "outputs" => [],
      "stateMutability" => "nonpayable",
      "type" => "function"
    }
  ]
  @change_version_function_signature "92dfbc49"
  @change_version_function_abi [
    %{
      "inputs" => [
        %{"internalType" => "address", "name" => "aspectId", "type" => "address"},
        %{
          "internalType" => "address",
          "name" => "accountAddr",
          "type" => "address"
        },
        %{"internalType" => "uint64", "name" => "version", "type" => "uint64"}
      ],
      "name" => "changeVersion",
      "outputs" => [],
      "stateMutability" => "nonpayable",
      "type" => "function"
    }
  ]

  def parse(transaction_params) do
    initial_acc = %{aspect_versions: [], aspect_transactions: [], aspect_bound_addresses: []}
    aspect_transaction_params = transaction_params |> Enum.filter(&(&1.to_address_hash == unquote(Aspect.constant())))

    if length(aspect_transaction_params) > 0 do
      raw_attrs =
        aspect_transaction_params
        |> Enum.reduce(initial_acc, &do_parse/2)

      aspects = filter_aspects(raw_attrs[:aspect_transactions], raw_attrs[:aspect_versions])

      %{
        aspects: aspects,
        aspect_versions: raw_attrs[:aspect_versions],
        aspect_bound_addresses: raw_attrs[:aspect_bound_addresses],
        aspect_transactions: raw_attrs[:aspect_transactions]
      }
    else
      %{
        aspects: [],
        aspect_versions: [],
        aspect_bound_addresses: [],
        aspect_transactions: []
      }
    end
  end

  defp filter_aspects(transactions, versions) do
    tx_map =
      transactions |> Enum.map(&%{hash: &1[:aspect_hash]}) |> Enum.uniq() |> Enum.map(&{&1.hash, &1}) |> Map.new()

    version_map = versions |> Enum.filter(& &1[:version]) |> Enum.map(&{&1.aspect_hash, &1}) |> Map.new()

    Map.merge(tx_map, version_map, fn key, val1, val2 ->
      Map.merge(val1, val2)
      |> Map.put(:hash, key)
      |> Map.drop([:aspect_hash])
    end)
    |> Map.values()
  end

  defp do_parse(
         params,
         %{
           aspect_versions: aspect_versions,
           aspect_transactions: aspect_transactions,
           aspect_bound_addresses: aspect_bound_addresses
         }
       ) do
    base_transaction_attrs = %{
      hash: params[:hash],
      block_number: params[:block_number],
      index: params[:transaction_index]
    }

    base_version_attrs = %{
      aspect_transaction_hash: params[:hash],
      block_number: params[:block_number],
      aspect_transaction_index: params[:transaction_index]
    }

    input = params[:input]

    case parse_function_method(input) do
      :unknown ->
        %{
          aspect_versions: aspect_versions,
          aspect_transactions: [Map.merge(base_transaction_attrs, %{type: :unknown}) | aspect_transactions],
          aspect_bound_addresses: aspect_bound_addresses
        }

      :operation ->
        %{
          aspect_versions: aspect_versions,
          aspect_transactions: [
            Map.merge(base_transaction_attrs, %{type: :operation, aspect_hash: "0x" <> String.slice(input, 34, 40)})
            | aspect_transactions
          ],
          aspect_bound_addresses: aspect_bound_addresses
        }

      :bind = method ->
        parsed_data = parse_function_input(method, input)

        %{
          aspect_versions: aspect_versions,
          aspect_transactions: [
            Map.merge(base_transaction_attrs, %{
              type: method,
              aspect_hash: parsed_data[:aspect_hash],
              version: parsed_data[:version]
            })
            | aspect_transactions
          ],
          aspect_bound_addresses: [
            Map.merge(parsed_data, %{
              checkpoint_block_number: params[:block_number],
              bind_block_number: params[:block_number],
              bind_aspect_transaction_hash: params[:hash],
              bind_aspect_transaction_index: params[:transaction_index]
            })
            | aspect_bound_addresses
          ]
        }

      :unbind = method ->
        parsed_data = parse_function_input(method, params[:input])

        %{
          aspect_versions: aspect_versions,
          aspect_transactions: [
            Map.merge(base_transaction_attrs, %{
              type: method,
              aspect_hash: parsed_data[:aspect_hash]
            })
            | aspect_transactions
          ],
          aspect_bound_addresses: [
            Map.merge(parsed_data, %{
              unbind_block_number: params[:block_number],
              unbind_aspect_transaction_hash: params[:hash],
              unbind_aspect_transaction_index: params[:transaction_index]
            })
            | aspect_bound_addresses
          ]
        }

      :deploy = method ->
        aspect_hash = generate_aspect_id(params[:from_address_hash], params[:nonce])
        parsed_data = parse_function_input(method, params[:input])

        %{
          aspect_versions: [
            base_version_attrs |> Map.merge(parsed_data) |> Map.merge(%{aspect_hash: aspect_hash}) | aspect_versions
          ],
          aspect_transactions: [
            Map.merge(base_transaction_attrs, %{
              type: method,
              aspect_hash: aspect_hash,
              version: parsed_data[:version]
            })
            | aspect_transactions
          ],
          aspect_bound_addresses: aspect_bound_addresses
        }

      :upgrade = method ->
        parsed_data = parse_function_input(method, params[:input])

        %{
          aspect_versions: [Map.merge(base_version_attrs, parsed_data) | aspect_versions],
          aspect_transactions: [
            Map.merge(base_transaction_attrs, %{
              type: method,
              aspect_hash: parsed_data[:aspect_hash]
            })
            | aspect_transactions
          ],
          aspect_bound_addresses: aspect_bound_addresses
        }

      :change_version = method ->
        parsed_data = parse_function_input(method, params[:input])

        %{
          aspect_versions: aspect_versions,
          aspect_transactions: [
            Map.merge(base_transaction_attrs, %{
              type: method,
              aspect_hash: parsed_data[:aspect_hash],
              version: parsed_data[:version]
            })
            | aspect_transactions
          ],
          aspect_bound_addresses: aspect_bound_addresses
        }
    end
  end

  defp parse_function_input(method, input) do
    selector = parse_function_selector(method)
    input_data = input |> String.slice(2..-1) |> Base.decode16!(case: :lower)
    result = ABI.decode(selector, input_data, :input)

    case selector.function do
      "bind" ->
        %{
          aspect_hash: "0x" <> (result |> Enum.at(0) |> Base.encode16(case: :lower)),
          version: Enum.at(result, 1),
          bound_address_hash: "0x" <> (result |> Enum.at(2) |> Base.encode16(case: :lower)),
          priority: Enum.at(result, 3)
        }

      "unbind" ->
        %{
          aspect_hash: "0x" <> (result |> Enum.at(0) |> Base.encode16(case: :lower)),
          bound_address_hash: "0x" <> (result |> Enum.at(1) |> Base.encode16(case: :lower))
        }

      "deploy" ->
        %{
          code: "0x" <> (result |> Enum.at(0) |> Base.encode16(case: :lower)),
          properties:
            result
            |> Enum.at(1)
            |> Enum.map(fn {k, v} -> {k, "0x" <> Base.encode16(v, case: :lower)} end)
            |> Enum.into(%{}),
          settlement_address_hash: "0x" <> (result |> Enum.at(2) |> Base.encode16(case: :lower)),
          proof: "0x" <> (result |> Enum.at(3) |> Base.encode16(case: :lower)),
          join_points: result |> Enum.at(4),
          version: 1
        }

      "upgrade" ->
        %{
          aspect_hash: "0x" <> (result |> Enum.at(0) |> Base.encode16(case: :lower)),
          code: "0x" <> (result |> Enum.at(1) |> Base.encode16(case: :lower)),
          properties:
            result
            |> Enum.at(2)
            |> Enum.map(fn {k, v} -> {k, "0x" <> Base.encode16(v, case: :lower)} end)
            |> Enum.into(%{}),
          join_points: result |> Enum.at(4)
        }

      "change_version" ->
        %{
          aspect_hash: "0x" <> (result |> Enum.at(0) |> Base.encode16(case: :lower)),
          address_hash: "0x" <> (result |> Enum.at(1) |> Base.encode16(case: :lower)),
          version: Enum.at(result, 2)
        }
    end
  end

  def decode_join_points(join_points) do
    [
      {"verify_tx", 1},
      {"pre_tx_execute", 2},
      {"pre_contract_call", 4},
      {"post_contract_call", 8},
      {"post_tx_execute", 16},
      {"post_tx_commit", 32}
    ]
    |> Enum.filter(fn {_name, value} -> (join_points &&& value) != 0 end)
    |> Enum.map(fn {name, _} -> name end)
  end

  defp parse_function_method(input) do
    case String.slice(input, 2..9) do
      @bind_function_signature -> :bind
      @unbind_function_signature -> :unbind
      @deploy_function_signature -> :deploy
      @upgrade_function_signature -> :upgrade
      @change_version_function_signature -> :change_version
      @operation_function_signature -> :operation
      _ -> :unknown
    end
  end

  defp parse_function_selector(method) do
    case method do
      :bind ->
        @bind_function_abi

      :unbind ->
        @unbind_function_abi

      :deploy ->
        @deploy_function_abi

      :upgrade ->
        @upgrade_function_abi

      :change_version ->
        @change_version_function_abi
    end
    |> ABI.parse_specification()
    |> List.first()
  end

  defp generate_aspect_id("0x" <> sender_address, nonce) do
    nonce_hex =
      case nonce do
        0 ->
          ""

        _ ->
          hex_nonce = Integer.to_string(nonce, 16)

          if rem(byte_size(hex_nonce), 2) == 1 do
            "0" <> hex_nonce
          else
            hex_nonce
          end
      end

    rlp_encoded =
      ExRLP.encode(
        [
          Base.decode16!(sender_address, case: :lower),
          Base.decode16!(nonce_hex)
        ],
        encoding: :hex
      )

    address =
      rlp_encoded
      |> Base.decode16!(case: :lower)
      |> ExKeccak.hash_256()
      |> Base.encode16(case: :lower)
      |> String.slice(24..-1)

    "0x" <> address
  end
end
