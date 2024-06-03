defmodule Explorer.Repo.Migrations.CreateAspectVersions do
  use Ecto.Migration

  def change do
    create table(:aspect_versions) do
      add(:version, :integer)
      add(:join_points, :smallint)
      add(:properties, :jsonb)
      add(:code, :bytea)
      add(:proof, :bytea)
      add(:aspect_transaction_index, :integer, null: false)
      add(:block_number, :integer, null: false)
      add(:settlement_address_hash, :bytea)

      add(
        :aspect_transaction_hash,
        references(:aspect_transactions, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false
      )

      add(:aspect_hash, references(:aspects, column: :hash, on_delete: :delete_all, type: :bytea), null: false)

      timestamps()
    end

    create(unique_index(:aspect_versions, [:aspect_hash, :version]))
  end
end
