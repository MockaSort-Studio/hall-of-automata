defmodule Livedata.Measurements.PubSubTest do
  use Livedata.DataCase, async: true

  @moduletag :integration

  alias Livedata.Measurements
  alias Livedata.Measurements.RawMeasurement
  alias Livedata.Projects.{Activity, Project}

  defp activity_id! do
    project =
      %Project{}
      |> Project.changeset(%{name: "P", status: "DRAFT", commissioned_at: DateTime.utc_now()})
      |> Repo.insert!()

    activity =
      %Activity{}
      |> Activity.changeset(project.id, %{
        name: "A",
        activity_type: "PERMANENT_REMOVAL",
        status: "REGISTERED",
        activity_period_start: ~D[2026-01-01],
        monitoring_period_start: ~D[2025-12-01]
      })
      |> Repo.insert!()

    activity.id
  end

  defp valid_attrs do
    %{
      "activity_id" => activity_id!(),
      "measured_at" => "2026-07-01T10:00:00Z",
      "method" => "core",
      "latitude" => "45.1",
      "longitude" => "7.6",
      "crs" => "EPSG:4326",
      "values_json" => ~s({"soc":2.3,"unit":"pct"})
    }
  end

  # @req: CRCF-21 — developer submissions must be visible to admin within seconds (KR 2.3).
  describe "PubSub broadcasts on \"measurements:new\"" do
    test "create_raw_measurement/1 broadcasts {:measurement_created, rm} on success" do
      Measurements.subscribe()
      attrs = valid_attrs()
      assert {:ok, %RawMeasurement{} = rm} = Measurements.create_raw_measurement(attrs)
      assert_receive {:measurement_created, ^rm}, 1_000
    end

    test "create_raw_measurement/1 does not broadcast on validation failure" do
      Measurements.subscribe()
      attrs = Map.put(valid_attrs(), "latitude", "")
      activity_id = attrs["activity_id"]
      assert {:error, _} = Measurements.create_raw_measurement(attrs)
      refute_receive {:measurement_created, %RawMeasurement{activity_id: ^activity_id}}, 200
    end

    test "create_raw_measurement/1 does not broadcast on duplicate rejection" do
      attrs = valid_attrs()
      activity_id = attrs["activity_id"]
      assert {:ok, _} = Measurements.create_raw_measurement(attrs)
      Measurements.subscribe()
      assert {:error, :duplicate} = Measurements.create_raw_measurement(attrs)
      refute_receive {:measurement_created, %RawMeasurement{activity_id: ^activity_id}}, 200
    end
  end
end
