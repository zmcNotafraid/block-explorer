defmodule Indexer.Fetcher.Aspect.UnbindAddress do
  @moduledoc """
  To update address bound aspect's unbound info, include: unbind block number, unbind transaction hash, unbind transaction index
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  require Logger

  import Ecto.Query

  alias Explorer.Repo
  alias Explorer.Chain.Aspect.BoundAddress
  alias Explorer.Chain.Aspect
  alias Indexer.{BufferedTask}

  @behaviour BufferedTask

  @max_batch_size 20
  @max_concurrency 4
  @defaults [
    flush_interval: :timer.minutes(1),
    max_concurrency: @max_concurrency,
    max_batch_size: @max_batch_size,
    task_supervisor: Indexer.Fetcher.Aspect.UnbindAddress.TaskSupervisor
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
    {:ok, acc} =
      Aspect.stream_unbind_addresses(
        initial,
        fn unbind_address, acc ->
          reducer.(unbind_address, acc)
        end,
        true
      )

    acc
  end

  @impl BufferedTask
  def run(entries, _) do
    entries
    |> Enum.each(fn entry ->
      from(ba in BoundAddress,
        where:
          ba.aspect_hash == ^entry.aspect_hash and ba.bound_address_hash == ^entry.bound_address_hash and
            ba.bind_block_number < ^entry.unbind_block_number and
            (is_nil(ba.unbind_block_number) or ba.unbind_block_number > ^entry.unbind_block_number)
      )
      |> Repo.update_all(
        set: [
          unbind_block_number: entry.unbind_block_number,
          unbind_aspect_transaction_hash: entry.unbind_aspect_transaction_hash,
          unbind_aspect_transaction_index: entry.unbind_aspect_transaction_index
        ]
      )
    end)
  end
end
