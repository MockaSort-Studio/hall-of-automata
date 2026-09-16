defmodule Livedata.Repo.Migrations.DropTimescaledb do
  use Ecto.Migration

  # On existing databases that ran the original create_raw_measurements migration,
  # TimescaleDB needs to be removed and the table converted to plain Postgres.
  # On fresh databases (create_raw_measurements now creates a plain table directly),
  # only the derived_measurement_sources FK needs to be added — it was previously
  # blocked by the hypertable composite PK and deferred to this migration.
  def up do
    has_timescaledb =
      repo().query!("SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'timescaledb')").rows ==
        [[true]]

    if has_timescaledb do
      execute "CREATE TABLE raw_measurements_bak AS
        SELECT id, activity_id, measured_at, source_type, content_hash,
               provenance, values, is_superseded, superseded_by, inserted_at
        FROM raw_measurements"

      execute "DROP TRIGGER IF EXISTS raw_measurements_immutable ON raw_measurements"
      execute "DROP FUNCTION IF EXISTS prevent_raw_measurement_mutation()"
      execute "DROP TABLE raw_measurements"
      execute "DROP EXTENSION IF EXISTS timescaledb CASCADE"

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

      execute "INSERT INTO raw_measurements
                 (id, activity_id, measured_at, source_type, content_hash,
                  provenance, values, is_superseded, superseded_by, inserted_at)
               SELECT id, activity_id, measured_at, source_type, content_hash,
                      provenance, values, is_superseded, superseded_by, inserted_at
               FROM raw_measurements_bak"

      execute "DROP TABLE raw_measurements_bak"

      # @req: CRCF-28
      create unique_index(:raw_measurements, [:content_hash])

      execute "CREATE INDEX raw_measurements_measured_at_idx
               ON raw_measurements USING BRIN (measured_at)"

      # @req: CRCF-26 — self-referential FK, now possible without the hypertable
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

      # @req: CRCF-25
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

    # @req: CRCF-33 — FK from derived_measurement_sources to raw_measurements.
    # Previously blocked by the TimescaleDB hypertable composite PK (id, measured_at);
    # now possible with a plain table. Guard with IF NOT EXISTS in case a future
    # migration adds it earlier in the sequence.
    execute """
    DO $$ BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'derived_measurement_sources_source_id_fkey'
          AND table_name = 'derived_measurement_sources'
      ) THEN
        ALTER TABLE derived_measurement_sources
          ADD CONSTRAINT derived_measurement_sources_source_id_fkey
          FOREIGN KEY (source_id) REFERENCES raw_measurements(id) ON DELETE RESTRICT;
      END IF;
    END $$;
    """
  end

  def down do
    execute "ALTER TABLE derived_measurement_sources
               DROP CONSTRAINT IF EXISTS derived_measurement_sources_source_id_fkey"
    execute "DROP TRIGGER IF EXISTS raw_measurements_immutable ON raw_measurements"
    execute "DROP FUNCTION IF EXISTS prevent_raw_measurement_mutation()"
    execute "ALTER TABLE raw_measurements
               DROP CONSTRAINT IF EXISTS raw_measurements_superseded_by_fkey"
    drop_if_exists constraint(:raw_measurements, :superseded_must_have_superseded_by)
    drop_if_exists constraint(:raw_measurements, :no_self_supersession)
    drop_if_exists index(:raw_measurements, [:content_hash])
    execute "DROP INDEX IF EXISTS raw_measurements_measured_at_idx"
    drop table(:raw_measurements)
    # Restoring the TimescaleDB hypertable is not supported in this down migration.
    # Re-run migrations from scratch (mix ecto.reset) to rebuild the pre-change schema.
  end
end
