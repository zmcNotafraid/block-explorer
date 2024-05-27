defmodule Explorer.Chain.Import.Runner.Aspect.BoundAddresses do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Aspect.Version.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.Aspect.BoundAddress
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [BoundAddress.t()]

  @impl Import.Runner
  def ecto_schema_module, do: BoundAddress

  @impl Import.Runner
  def option_key, do: :aspect_bound_addresses

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  @impl Import.Runner
  def run(multi, changes_list, %{timestamps: timestamps} = options) do
    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    Multi.run(multi, :aspect_bound_addresses, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :aspect_referencing,
        :bound_addresses,
        :aspects_bound_addresses
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) ::
          {:ok, [BoundAddress.t()]}
          | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        changes_list,
        conflict_target: [:bind_block_number, :bind_aspect_transaction_index],
        on_conflict: on_conflict,
        for: BoundAddress,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end

  defp default_on_conflict do
    from(
      bound_address in BoundAddress,
      update: [
        set: [
          version: fragment("EXCLUDED.version"),
          priority: fragment("EXCLUDED.priority"),
          unbind_block_number: fragment("EXCLUDED.unbind_block_number"),
          unbind_aspect_transaction_index: fragment("EXCLUDED.unbind_aspect_transaction_index"),
          unbind_aspect_transaction_hash: fragment("EXCLUDED.unbind_aspect_transaction_hash"),
          bound_address_hash: fragment("EXCLUDED.bound_address_hash"),
          aspect_hash: fragment("EXCLUDED.aspect_hash"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", bound_address.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", bound_address.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.version, EXCLUDED.priority, EXCLUDED.unbind_block_number, EXCLUDED.unbind_aspect_transaction_index, EXCLUDED.unbind_aspect_transaction_hash, EXCLUDED.bound_address_hash, EXCLUDED.aspect_hash) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?)",
          bound_address.version,
          bound_address.priority,
          bound_address.unbind_block_number,
          bound_address.unbind_aspect_transaction_index,
          bound_address.unbind_aspect_transaction_hash,
          bound_address.bound_address_hash,
          bound_address.aspect_hash
        )
    )
  end
end
