defmodule Explorer.Chain.Aspect do
  @moduledoc """
  A stored representation of aspect lastest version.
  """

  use Explorer.Schema

  alias Ecto.Association.NotLoaded
  alias Ecto.Changeset
  alias Explorer.Chain.{Aspect, Data, Hash}
  alias Explorer.{Chain, PagingOptions, Repo}

  @constant "0x0000000000000000000000000000000000a27e14"

  @optional_attrs ~w(properties proof join_points settlement_address_hash code version)a
  @required_attrs ~w(hash)a
  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
   * `hash` - aspect ID
   * `version` - aspect lastest version
   * `properties` - aspect latest deployed properties
   * `join_points` - aspect latest join_points
   * `code` - aspect latest deployed Bytecode of the Aspect's WASM artifact
  """

  @primary_key false
  typed_schema "aspects" do
    field(:hash, Hash.Address, primary_key: true)
    field(:settlement_address_hash, Hash.Address)
    field(:properties, :map)
    field(:version, :integer)
    field(:code, Data)
    field(:proof, :binary)
    field(:join_points, :integer)

    has_many(:transactions, Aspect.Transaction, foreign_key: :aspect_hash, references: :hash)
    has_many(:versions, Aspect.Version, foreign_key: :aspect_hash, references: :hash)
    has_many(:bound_addresses, Aspect.BoundAddress, foreign_key: :aspect_hash, references: :hash)

    timestamps()
  end

  def changeset(%__MODULE__{} = aspect, attrs) do
    aspect
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:hash)
  end

  def constant, do: @constant

  def find_by_hash(aspect_hash) do
    Aspect |> Repo.get_by(hash: aspect_hash)
  end
end
