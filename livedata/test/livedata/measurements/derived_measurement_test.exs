defmodule Livedata.Measurements.DerivedMeasurementTest do
  use Livedata.DataCase, async: false

  @moduletag :integration

  alias Livedata.Measurements.DerivedMeasurement
  alias Livedata.Measurements.DerivedMeasurementSource
  alias Livedata.Measurements.RawMeasurement
  alias Livedata.Projects.Activity
  alias Livedata.Projects.Project

  @valid_boundary %Geo.MultiPolygon{
    coordinates: [
      [
        [{0.0, 0.0}, {1.0, 0.0}, {1.0, 1.0}, {0.0, 1.0}, {0.0, 0.0}]
      ]
    ],
    srid: 4326
  }

  @project_attrs %{
    name: "Test Project",
    status: "DRAFT",
    spatial_boundary: @valid_boundary,
    commissioned_at: ~U[2026-01-01 00:00:00.000000Z]
  }

  @activity_attrs %{
    name: "Test Activity",
    activity_type: "PERMANENT_REMOVAL",
    storage_duration_tier: "PERMANENT",
    status: "REGISTERED",
    activity_period_start: ~D[2026-01-01],
    monitoring_period_start: ~D[2025-12-01]
  }

  @computation_id "00000000-0000-0000-0000-000000000001"

  @valid_attrs %{
    computation_id: @computation_id,
    type: "co2_total",
    values: %{"co2_kg" => 100.0}
  }

  defp insert_project!() do
    %Project{} |> Project.changeset(@project_attrs) |> Repo.insert!()
  end

  defp insert_activity!(project) do
    %Activity{} |> Activity.changeset(project.id, @activity_attrs) |> Repo.insert!()
  end

  defp insert_derived!(activity, attrs \\ %{}) do
    %DerivedMeasurement{}
    |> DerivedMeasurement.changeset(activity.id, Map.merge(@valid_attrs, attrs))
    |> Repo.insert!()
  end

  defp insert_raw!(activity, n) do
    hash = "raw#{n}" <> String.duplicate("0", 59)

    %RawMeasurement{}
    |> RawMeasurement.changeset(activity.id, %{
      measured_at: ~U[2026-06-01 12:00:00.000000Z],
      source_type: "MANUAL_ENTRY",
      content_hash: hash,
      provenance: %{"operator" => "test"},
      values: %{"co2_kg" => 10.0}
    })
    |> Repo.insert!()
  end

  defp uuid_bin(id), do: Ecto.UUID.dump!(id)

  describe "DerivedMeasurement — persistence" do
    test "valid derived_measurement linked to an existing activity can be inserted and retrieved by id" do
      project = insert_project!()
      activity = insert_activity!(project)

      assert {:ok, m} =
               %DerivedMeasurement{}
               |> DerivedMeasurement.changeset(activity.id, @valid_attrs)
               |> Repo.insert()

      assert Repo.get(DerivedMeasurement, m.id) != nil
    end

    # @req: CRCF-19
    test "id is auto-generated as UUID on insert" do
      project = insert_project!()
      activity = insert_activity!(project)
      m = insert_derived!(activity)

      assert is_binary(m.id)
      assert {:ok, _} = Ecto.UUID.cast(m.id)
    end

    # @req: CRCF-20
    test "inserted_at is UTC on insert" do
      project = insert_project!()
      activity = insert_activity!(project)
      m = insert_derived!(activity)

      assert m.inserted_at.time_zone == "Etc/UTC"
    end

    # @req: CRCF-21
    test "activity_id is required; insert without it is rejected" do
      changeset = DerivedMeasurement.changeset(%DerivedMeasurement{}, nil, @valid_attrs)
      refute changeset.valid?
      assert %{activity_id: [_ | _]} = errors_on(changeset)
    end

    # @req: CRCF-33
    test "computation_id is required; insert without it is rejected" do
      project = insert_project!()
      activity = insert_activity!(project)

      changeset =
        DerivedMeasurement.changeset(
          %DerivedMeasurement{},
          activity.id,
          Map.delete(@valid_attrs, :computation_id)
        )

      refute changeset.valid?
      assert %{computation_id: [_ | _]} = errors_on(changeset)
    end

    test "type is required; insert without it is rejected" do
      project = insert_project!()
      activity = insert_activity!(project)

      changeset =
        DerivedMeasurement.changeset(
          %DerivedMeasurement{},
          activity.id,
          Map.delete(@valid_attrs, :type)
        )

      refute changeset.valid?
      assert %{type: [_ | _]} = errors_on(changeset)
    end

    # @req: CRCF-27
    test "values is required; insert without it is rejected" do
      project = insert_project!()
      activity = insert_activity!(project)

      changeset =
        DerivedMeasurement.changeset(
          %DerivedMeasurement{},
          activity.id,
          Map.delete(@valid_attrs, :values)
        )

      refute changeset.valid?
      assert %{values: [_ | _]} = errors_on(changeset)
    end

    test "is_superseded defaults to false" do
      project = insert_project!()
      activity = insert_activity!(project)
      m = insert_derived!(activity)

      assert m.is_superseded == false
    end

    # @req: CRCF-26
    test "is_superseded = true with superseded_by = nil is rejected" do
      project = insert_project!()
      activity = insert_activity!(project)

      changeset =
        DerivedMeasurement.changeset(%DerivedMeasurement{}, activity.id, %{
          computation_id: @computation_id,
          type: "co2_total",
          values: %{"co2_kg" => 1.0},
          is_superseded: true
        })

      refute changeset.valid?
      assert %{superseded_by: [_ | _]} = errors_on(changeset)
    end

    # @req: CRCF-26
    test "superseded_by = id (self-reference) is rejected" do
      self_id = Ecto.UUID.generate()
      project = insert_project!()
      activity = insert_activity!(project)

      changeset =
        DerivedMeasurement.changeset(%DerivedMeasurement{id: self_id}, activity.id, %{
          computation_id: @computation_id,
          type: "co2_total",
          values: %{"co2_kg" => 1.0},
          superseded_by: self_id
        })

      refute changeset.valid?
      assert %{superseded_by: [_ | _]} = errors_on(changeset)
    end

    # @req: CRCF-25
    test "UPDATE on any derived_measurement row is rejected at DB level" do
      project = insert_project!()
      activity = insert_activity!(project)
      m = insert_derived!(activity)

      assert_raise Postgrex.Error, ~r/derived_measurements is append-only/i, fn ->
        Repo.query!(
          "UPDATE derived_measurements SET type = 'changed' WHERE id = $1",
          [uuid_bin(m.id)]
        )
      end
    end

    # @req: CRCF-25
    test "DELETE on any derived_measurement row is rejected at DB level" do
      project = insert_project!()
      activity = insert_activity!(project)
      m = insert_derived!(activity)

      assert_raise Postgrex.Error, ~r/derived_measurements is append-only/i, fn ->
        Repo.query!("DELETE FROM derived_measurements WHERE id = $1", [uuid_bin(m.id)])
      end
    end
  end

  describe "DerivedMeasurementSource — persistence" do
    test "a derived_measurement_source row linking a derived record to a raw record can be inserted" do
      project = insert_project!()
      activity = insert_activity!(project)
      derived = insert_derived!(activity)
      raw = insert_raw!(activity, 1)

      assert {:ok, _} =
               %DerivedMeasurementSource{}
               |> DerivedMeasurementSource.changeset(%{
                 derived_id: derived.id,
                 source_id: raw.id
               })
               |> Repo.insert()
    end

    # @req: CRCF-33
    test "source_id UNIQUE constraint — second row with same source_id is rejected" do
      project = insert_project!()
      activity = insert_activity!(project)
      derived1 = insert_derived!(activity)
      derived2 = insert_derived!(activity, %{computation_id: Ecto.UUID.generate()})
      raw = insert_raw!(activity, 2)

      %DerivedMeasurementSource{}
      |> DerivedMeasurementSource.changeset(%{derived_id: derived1.id, source_id: raw.id})
      |> Repo.insert!()

      assert {:error, changeset} =
               %DerivedMeasurementSource{}
               |> DerivedMeasurementSource.changeset(%{
                 derived_id: derived2.id,
                 source_id: raw.id
               })
               |> Repo.insert()

      assert %{source_id: [_ | _]} = errors_on(changeset)
    end

    # @req: CRCF-24
    test "full traceability chain — source raw measurements are reachable via derived_measurement_sources" do
      project = insert_project!()
      activity = insert_activity!(project)
      derived = insert_derived!(activity)
      raw1 = insert_raw!(activity, 3)
      raw2 = insert_raw!(activity, 4)

      %DerivedMeasurementSource{}
      |> DerivedMeasurementSource.changeset(%{derived_id: derived.id, source_id: raw1.id})
      |> Repo.insert!()

      %DerivedMeasurementSource{}
      |> DerivedMeasurementSource.changeset(%{derived_id: derived.id, source_id: raw2.id})
      |> Repo.insert!()

      source_ids =
        Repo.all(
          from(s in DerivedMeasurementSource,
            where: s.derived_id == ^derived.id,
            select: s.source_id
          )
        )

      assert length(source_ids) == 2
      assert raw1.id in source_ids
      assert raw2.id in source_ids
    end
  end
end
