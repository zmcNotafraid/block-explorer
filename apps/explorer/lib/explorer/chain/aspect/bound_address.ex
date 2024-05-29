defmodule Explorer.Chain.Aspect.BoundAddress do
  @moduledoc """
  Aspect bound addresses.
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.Chain.{Aspect, Address, Hash}

  @typedoc """
  * `aspect` - the `t:Explorer.Chain.Aspect.t/0` .
  * `aspect_hash` - foreign key for `address`.
  * `version` - the version of aspect.
  * `priority` - the lowest priority number being executed first, an unsigned 8-bit integer.
  """

  typed_schema "aspect_bound_addresses" do
    field(:priority, :integer)
    field(:version, :integer)
    field(:checkpoint_block_number, :integer)
    field(:bind_block_number, :integer)
    field(:unbind_block_number, :integer)
    field(:bind_aspect_transaction_index, :integer)
    field(:unbind_aspect_transaction_index, :integer)

    belongs_to(:address, Address, foreign_key: :bound_address_hash, references: :hash, type: Hash.Address, null: false)
    belongs_to(:aspect, Aspect, foreign_key: :aspect_hash, references: :hash, type: Hash.Address, null: false)

    belongs_to(:aspect_transaction, Aspect.Transaction,
      foreign_key: :bind_aspect_transaction_hash,
      references: :hash,
      type: Hash.Full
    )

    belongs_to(:aspect_unbind_transaction, Aspect.Transaction,
      foreign_key: :unbind_aspect_transaction_hash,
      references: :hash,
      type: Hash.Full
    )

    timestamps()
  end

  @required_fields ~w(aspect_hash bound_address_hash)a
  @optional_fields ~w(version unbind_block_number unbind_aspect_transaction_hash unbind_aspect_transaction_index bind_aspect_transaction_hash bind_block_number bind_aspect_transaction_index priority checkpoint_block_number)a
  @allowed_fields @required_fields ++ @optional_fields

  def changeset(%__MODULE__{} = struct, params \\ %{}) do
    struct
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:aspect_hash)
    |> unique_constraint([:bind_block_number, :bind_aspect_transaction_index])
  end
end
