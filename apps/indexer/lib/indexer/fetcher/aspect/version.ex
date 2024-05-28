defmodule Indexer.Fetcher.Aspect.Version do
  @moduledoc """
  Finds and updates replaced transactions.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  require Logger

  import Ecto.Query
  import Explorer.Chain.Import, only: [timestamps: 0]

  alias Ecto.Multi
  alias Explorer.{Repo}
  alias Explorer.Chain.Aspect.Version
  alias Explorer.Chain.Aspect
  alias Indexer.{BufferedTask}

  @behaviour BufferedTask

  @max_batch_size 1
  @max_concurrency 4
  @defaults [
    flush_interval: :timer.minutes(1),
    max_concurrency: @max_concurrency,
    max_batch_size: @max_batch_size,
    task_supervisor: Indexer.Fetcher.Aspect.Version.TaskSupervisor
  ]

  @doc false
  def child_spec([init_options, gen_server_options]) do
    merged_init_opts =
      @defaults
      |> Keyword.merge(init_options)
      |> Keyword.put(:state, {})

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial_acc, reducer, _) do
    {:ok, acc} =
      Aspect.stream_unversioned_aspect_hashes(
        initial_acc,
        fn aspect_hash, acc ->
          reducer.(aspect_hash, acc)
        end,
        true
      )

    acc
  end

  @impl BufferedTask
  def run([aspect_hash], _) do
    ranked_versions =
      from(version in Version,
        where: version.aspect_hash == ^aspect_hash,
        select: %{
          id: version.id,
          code: version.code,
          properties: version.properties,
          join_points: version.join_points,
          aspect_hash: version.aspect_hash,
          block_number: version.block_number,
          aspect_transaction_hash: version.aspect_transaction_hash,
          aspect_transaction_index: version.aspect_transaction_index,
          version:
            fragment(
              "RANK() OVER (ORDER BY ? ASC,? ASC)",
              version.block_number,
              version.aspect_transaction_index
            )
        }
      )
      |> Repo.all()

    version_attrs = Enum.filter(ranked_versions, &(&1[:version] != 1)) |> Enum.map(&Map.merge(&1, timestamps()))
    aspect = Repo.get_by(Aspect, hash: aspect_hash)
    latest_version = List.last(version_attrs)
    changeset = Aspect.changeset(aspect, latest_version)

    Multi.new()
    |> Multi.insert_all(:update_versions, Version, version_attrs,
      on_conflict: {:replace, [:version, :updated_at]},
      conflict_target: :id
    )
    |> Multi.update(:update_aspect, changeset)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        :ok

      _ ->
        {:retry, [aspect_hash]}
    end
  end
end
