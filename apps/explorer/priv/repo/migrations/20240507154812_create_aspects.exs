defmodule Explorer.Repo.Migrations.CreateAspects do
  use Ecto.Migration

  def change do
    create table(:aspects, primary_key: false) do
      add(:hash, :bytea, null: false, primary_key: true)
      add(:version, :integer)
      add(:join_points, :smallint)
      add(:properties, :jsonb)
      add(:code, :bytea)
      add(:proof, :bytea)
      add(:settlement_address_hash, :bytea)

      timestamps()
    end
  end
end
