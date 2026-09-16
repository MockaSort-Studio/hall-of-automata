defmodule Livedata.Repo.Migrations.CreateRawMeasurements do
  use Ecto.Migration

  def up do
    # @req: CRCF-04
    execute "CREATE TYPE source_type AS ENUM ('MANUAL_ENTRY', 'REMOTE_SENSING', 'MODEL_OUTPUT')"

    create table(:raw_measurements, primary_key: false) do
      # @req: CRCF-19
      add :id, :uuid, null: false, primary_key: true, default: fragment("gen_random_uuid()")
      # @req: CRCF-21
      add :activity_id, references(:activities, type: :uuid, on_delete: :restrict), null: false
      # @req: CRCF-20
      add :measured_at, :utc_datetime_usec, null: false
      # @req: CRCF-04
      add :source_type, :source_type, null: false
      # @req: CRCF-28
      add :content_hash, :text, null: false
      # @req: CRCF-04, CRCF-07
      add :provenance, :map, null: false
      # @req: CRCF-27
      add :values, :map, null: false
      # @req: CRCF-26
      add :is_superseded, :boolean, null: false, default: false
      # @req: CRCF-26
      add :superseded_by, :uuid, null: true
      # @req: CRCF-20
      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    # @req: CRCF-28
    create unique_index(:raw_measurements, [:content_hash])

    # BRIN index on measured_at — cheaper than B-tree for this append-only,
    # naturally time-ordered table. Covers staleness-monitoring range scans and
    # ORDER BY measured_at DESC queries at the cost of less precise block pruning.
    execute "CREATE INDEX raw_measurements_measured_at_idx ON raw_measurements USING BRIN (measured_at)"

    # @req: CRCF-26 — self-referential FK
    execute "ALTER TABLE raw_measurements
               ADD CONSTRAINT raw_measurements_superseded_by_fkey
               FOREIGN KEY (superseded_by) REFERENCES raw_measurements(id)"

    # @req: CRCF-26
    create constraint(:raw_measurements, :superseded_must_have_superseded_by,
             check: "NOT is_superseded OR superseded_by IS NOT NULL"
           )

    # @req: CRCF-26
    create constraint(:raw_measurements, :no_self_supersession,
             check: "superseded_by IS DISTINCT FROM id"
           )

    # @req: CRCF-25 — append-only enforcement via DB trigger
    execute """
    CREATE OR REPLACE FUNCTION prevent_raw_measurement_mutation()
    RETURNS trigger AS $$
    BEGIN
      RAISE EXCEPTION 'raw_measurements is append-only: mutations are forbidden';
    END;
    $$ LANGUAGE plpgsql
    """

    execute """
    CREATE TRIGGER raw_measurements_immutable
    BEFORE UPDATE OR DELETE ON raw_measurements
    FOR EACH ROW EXECUTE FUNCTION prevent_raw_measurement_mutation()
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS raw_measurements_immutable ON raw_measurements"
    execute "DROP FUNCTION IF EXISTS prevent_raw_measurement_mutation()"
    drop table(:raw_measurements)
    execute "DROP TYPE IF EXISTS source_type"
  end
end
