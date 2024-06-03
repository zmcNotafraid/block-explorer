defmodule Explorer.Repo.Migrations.CreateAspectTransactions do
  use Ecto.Migration

  def change do
    create table(:aspect_transactions, primary_key: false) do
      add(:version, :integer)
      add(:block_number, :integer, null: false)
      add(:index, :integer, null: false)
      add(:hash, :bytea, null: false, primary_key: true)
      add(:type, :string, null: false)

      add(:aspect_hash, references(:aspects, column: :hash, on_delete: :delete_all, type: :bytea))

      timestamps()
    end
  end
end
