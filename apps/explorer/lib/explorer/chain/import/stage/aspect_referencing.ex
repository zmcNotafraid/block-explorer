defmodule Explorer.Chain.Import.Stage.AspectReferencing do
  @moduledoc """
  Imports any tables that reference `t:Explorer.Chain.Block.t/0` and that were
  imported by `Explorer.Chain.Import.Stage.AddressesBlocksCoinBalances`.
  """

  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage
  @default_runners [
    Runner.Aspects,
    Runner.Aspect.Transactions,
    Runner.Aspect.BoundAddresses,
    Runner.Aspect.Versions
  ]

  @impl Stage
  def runners do
    @default_runners
  end

  @impl Stage
  def all_runners do
    @default_runners
  end

  @impl Stage
  def multis(runner_to_changes_list, options) do
    {final_multi, final_remaining_runner_to_changes_list} =
      Stage.single_multi(runners(), runner_to_changes_list, options)

    {[final_multi], final_remaining_runner_to_changes_list}
  end
end
