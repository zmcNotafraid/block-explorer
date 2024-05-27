defmodule Explorer.Chain.Import.Runner.Aspect.Versions do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Aspect.Version.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.Aspect.Version
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Version.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Version

  @impl Import.Runner
  def option_key, do: :aspect_versions

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

    Multi.run(multi, :aspect_versions, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :aspect_referencing,
        :versions,
        :aspects_versions
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
          {:ok, [Version.t()]}
          | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce Log ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.block_number, &1.aspect_transaction_index})

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: [:aspect_hash, :version],
        on_conflict: on_conflict,
        for: Version,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end

  defp default_on_conflict do
    from(
      version in Version,
      update: [
        set: [
          settlement_address_hash: fragment("EXCLUDED.settlement_address_hash"),
          properties: fragment("EXCLUDED.properties"),
          code: fragment("EXCLUDED.code"),
          proof: fragment("EXCLUDED.proof"),
          join_points: fragment("EXCLUDED.join_points"),
          block_number: fragment("EXCLUDED.block_number"),
          aspect_transaction_index: fragment("EXCLUDED.aspect_transaction_index"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", version.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", version.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.settlement_address_hash, EXCLUDED.properties, EXCLUDED.code, EXCLUDED.proof, EXCLUDED.join_points, EXCLUDED.block_number, EXCLUDED.aspect_transaction_index) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?)",
          version.settlement_address_hash,
          version.properties,
          version.code,
          version.proof,
          version.join_points,
          version.block_number,
          version.aspect_transaction_index
        )
    )
  end
end
