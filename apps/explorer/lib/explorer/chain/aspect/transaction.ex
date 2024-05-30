defmodule Explorer.Chain.Aspect.Transaction do
  @moduledoc """
  Aspect transactions.
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.Chain.{Aspect, Hash}

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
end
