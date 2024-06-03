defmodule Explorer.Chain.Import.Runner.Aspects do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Aspect.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Import, Aspect}
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Aspect.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Aspect

  @impl Import.Runner
  def option_key, do: :aspects

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

    Multi.run(multi, :aspects, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :aspect_referencing,
        :aspects,
        :aspects
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
          {:ok, [Aspect.t()]}
          | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    # on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        changes_list,
        conflict_target: [:hash],
        on_conflict: :nothing,
        for: Aspect,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end

  defp default_on_conflict do
    from(
      aspect in Aspect,
      update: [
        set: [
          settlement_address_hash: fragment("EXCLUDED.settlement_address_hash"),
          properties: fragment("EXCLUDED.properties"),
          version: fragment("EXCLUDED.version"),
          code: fragment("EXCLUDED.code"),
          proof: fragment("EXCLUDED.proof"),
          join_points: fragment("EXCLUDED.join_points"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", aspect.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", aspect.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.settlement_address_hash, EXCLUDED.properties, EXCLUDED.version, EXCLUDED.code, EXCLUDED.proof, EXCLUDED.join_points) IS DISTINCT FROM (?, ?, ?, ?, ?, ?)",
          aspect.settlement_address_hash,
          aspect.properties,
          aspect.version,
          aspect.code,
          aspect.proof,
          aspect.join_points
        )
    )
  end
end
