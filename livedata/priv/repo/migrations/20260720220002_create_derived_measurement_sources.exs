defmodule Livedata.Repo.Migrations.CreateDerivedMeasurementSources do
  use Ecto.Migration

  def up do
    create table(:derived_measurement_sources, primary_key: false) do
      # @req: CRCF-24
      add :derived_id,
          references(:derived_measurements, type: :uuid, on_delete: :restrict),
          null: false

      # @req: CRCF-33
      # FK to raw_measurements added in 20260912000001_drop_timescaledb, which is the
      # first migration where raw_measurements has a plain single-column PK.
      add :source_id, :uuid, null: false
    end

    execute "ALTER TABLE derived_measurement_sources ADD PRIMARY KEY (derived_id, source_id)"

    # @req: CRCF-33 — single-consumption: one raw measurement cannot contribute to more than one derived result
    create unique_index(:derived_measurement_sources, [:source_id])
  end

  def down do
    drop table(:derived_measurement_sources)
  end
end
