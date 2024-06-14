defmodule Explorer.Chain.Aspect.Version do
  @moduledoc """
  Aspect deployed version list.
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.Chain.{Aspect, Hash, Data}

  @typedoc """
   * `aspect` - the `t:Explorer.Chain.Aspect.t/0` .
   * `aspect_hash` - foreign key for `address`.
   * `version` - aspect version
   * `properties` - aspect deployed properties
   * `join_points` - aspect join_points
   * `code` - aspect deployed Bytecode of the Aspect's WASM artifact
  """

  typed_schema "aspect_versions" do
    field(:properties, :map)
    field(:version, :integer)
    field(:code, Data)
    field(:join_points, :integer)
    field(:proof, :binary)
    field(:aspect_transaction_index, :integer)
    field(:block_number, :integer)
    field(:settlement_address_hash, Hash.Address)

    belongs_to(:aspect, Aspect, foreign_key: :aspect_hash, references: :hash, type: Hash.Address, null: false)

    belongs_to(:aspect_transaction, Aspect.Transaction,
      foreign_key: :aspect_transaction_hash,
      references: :hash,
      type: Hash.Full,
      null: false
    )

    timestamps()
  end

  @required_fields ~w(aspect_hash aspect_transaction_hash aspect_transaction_index block_number)a
  @optional_fields ~w(code proof properties settlement_address_hash version join_points)a
  @allowed_fields @required_fields ++ @optional_fields

  def changeset(%__MODULE__{} = struct, params \\ %{}) do
    struct
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:aspect_hash)
    |> unique_constraint([:aspect_hash, :version])
  end
end
