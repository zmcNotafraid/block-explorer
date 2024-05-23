defmodule Explorer.Repo.Migrations.CreateAspectBoundAddresses do
  use Ecto.Migration

  def change do
    create table(:aspect_bound_addresses) do
      add(:version, :integer)
      add(:priority, :smallint)
      add(:checkpoint_block_number, :integer)
      add(:bind_block_number, :integer)
      add(:bind_aspect_transaction_index, :integer)

      add(
        :bind_aspect_transaction_hash,
        references(:aspect_transactions, column: :hash, on_delete: :delete_all, type: :bytea)
      )

      add(:unbind_block_number, :integer)
      add(:unbind_aspect_transaction_index, :integer)

      add(
        :unbind_aspect_transaction_hash,
        references(:aspect_transactions, column: :hash, on_delete: :delete_all, type: :bytea)
      )

      add(:bound_address_hash, references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea), null: false)
      add(:aspect_hash, references(:aspects, column: :hash, on_delete: :delete_all, type: :bytea), null: false)

      timestamps()
    end

    create(unique_index(:aspect_bound_addresses, [:bind_block_number, :bind_aspect_transaction_index]))
  end
end
