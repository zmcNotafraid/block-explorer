defmodule Indexer.Fetcher.Aspect.Transaction do
  @moduledoc """
  If a transction handled by an aspect, save this transaction to aspect_transactions table.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  require Logger

  import Ecto.Query

  alias Ecto.Multi
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Aspect.BoundAddress
  alias Explorer.Chain.{Aspect, Transaction}
  alias Explorer.Chain.Aspect.Transaction, as: AspectTransaction
  alias Indexer.{BufferedTask}

  @behaviour BufferedTask

  @default_batch_number 100

  @max_batch_size 100
  @max_concurrency 10
  @defaults [
    flush_interval: :timer.minutes(2),
    max_concurrency: @max_concurrency,
    max_batch_size: @max_batch_size,
    task_supervisor: Indexer.Fetcher.Aspect.Transaction.TaskSupervisor
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
  def init(initial, reducer, _) do
    if Chain.indexed_ratio_blocks() |> Chain.finished_indexing_from_ratio?() do
      {:ok, acc} =
        Aspect.stream_unhandled_aspect_transaction(
          initial,
          fn bound_address, acc ->
            reducer.(bound_address, acc)
          end,
          true
        )

      acc
    else
      []
    end
  end

  @impl BufferedTask
  def run(entries, _) do
    {:ok, number, _timestamp} = Chain.last_db_block_status()

    entries
    |> Enum.each(fn %BoundAddress{
                      unbind_block_number: unbind_block_number,
                      checkpoint_block_number: checkpoint_block_number,
                      bound_address_hash: address_hash
                    } = bound_address ->
      end_block_number = cal_end_block_number(checkpoint_block_number, unbind_block_number, number)

      attrs =
        from(t in Transaction,
          where:
            t.block_number > ^checkpoint_block_number and t.block_number <= ^end_block_number and
              (t.from_address_hash == ^address_hash or t.to_address_hash == ^address_hash),
          select: %{hash: t.hash, block_number: t.block_number, index: t.index}
        )
        |> Repo.all()
        |> Enum.map(fn tx -> %{hash: tx.hash, type: :handle, block_nubmer: tx.block_number, index: tx.index} end)

      changeset = BoundAddress.changeset(bound_address, %{checkpoint_block_number: end_block_number})

      Multi.new()
      |> Multi.insert_all(:handled_transactions, AspectTransaction, attrs,
        on_conflict: :nothing,
        conflict_target: :hash
      )
      |> Multi.update(:update_bound_address, changeset)
      |> Repo.transaction()
      |> case do
        {:ok, _} ->
          :ok

        _ ->
          {:retry, [bound_address]}
      end
    end)
  end

  defp cal_end_block_number(checkpoint_block_number, unbind_block_number, db_latest_number) do
    init_end_number = checkpoint_block_number + @default_batch_number

    case unbind_block_number do
      nil -> Enum.min([init_end_number, db_latest_number])
      _ -> Enum.min([init_end_number, unbind_block_number])
    end
  end
end
