defmodule Explorer.Chain.Aspect.Transaction do
  @moduledoc """
  Aspect transactions.
  """

  use Explorer.Schema

  import Ecto.Changeset
  import Explorer.Chain.Transaction, only: [fee: 2]

  alias Explorer.Chain.{Aspect, Hash}
  alias Explorer.PagingOptions
  alias Explorer.Chain.Transaction, as: ChainTransaction

  @typedoc """
  * `aspect` - the `t:Explorer.Chain.Aspect.t/0` .
  * `aspect_hash` - foreign key for `address`.
  * `version` - the version of aspect.
  """

  @primary_key false
  typed_schema "aspect_transactions" do
    field(:hash, Hash.Full, null: false)
    field(:version, :integer)
    field(:block_number, :integer)
    field(:index, :integer)
    field(:type, Ecto.Enum, values: [:bind, :unbind, :deploy, :upgrade, :change_version, :operation, :handle, :unknown])

    belongs_to(:aspect, Aspect, foreign_key: :aspect_hash, references: :hash, type: Hash.Address)

    timestamps()
  end

  @required_fields ~w(hash type block_number index)a
  @optional_fields ~w(version aspect_hash)a
  @allowed_fields @required_fields ++ @optional_fields

  def changeset(%__MODULE__{} = struct, params \\ %{}) do
    struct
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:aspect_hash)
  end

  @spec list_transactions(String.t()) :: Ecto.Query.t()
  def list_transactions(aspect_hash) do
    from(transaction in __MODULE__,
      join: ct in ChainTransaction,
      on: ct.hash == transaction.hash,
      where: transaction.aspect_hash == ^aspect_hash,
      select: %{
        hash: transaction.hash,
        type: transaction.type,
        block_number: transaction.block_number,
        index: transaction.index,
        from_address_hash: ct.from_address_hash,
        to_address_hash: ct.to_address_hash,
        value: ct.value,
        gas_price: ct.gas_price,
        gas_used: ct.gas_used
      },
      order_by: [desc: :block_number, desc: :index]
    )
  end

  @spec page_transaction(Ecto.Query.t() | atom, Explorer.PagingOptions.t()) :: Ecto.Query.t()
  def page_transaction(query, %PagingOptions{key: nil}), do: query

  def page_transaction(query, %PagingOptions{key: {block_number, index}, is_index_in_asc_order: true}) do
    where(
      query,
      [transaction],
      transaction.block_number < ^block_number or
        (transaction.block_number == ^block_number and transaction.index > ^index)
    )
  end

  def page_transaction(query, %PagingOptions{key: {block_number, index}}) do
    where(
      query,
      [transaction],
      transaction.block_number < ^block_number or
        (transaction.block_number == ^block_number and transaction.index < ^index)
    )
  end
end
