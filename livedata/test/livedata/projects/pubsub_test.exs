defmodule Livedata.Projects.PubSubTest do
  use Livedata.DataCase, async: true

  @moduletag :integration

  alias Livedata.Projects
  alias Livedata.Projects.{Methodology, Project}

  defp insert_project(name) do
    %Project{}
    |> Project.changeset(%{name: name, commissioned_at: DateTime.utc_now()})
    |> Repo.insert!()
  end

  defp insert_methodology do
    Repo.insert!(
      Methodology.changeset(%Methodology{}, %{
        name: "M#{System.unique_integer([:positive])}"
      })
    )
  end

  defp activity_params(overrides \\ %{}) do
    Map.merge(
      %{
        "activity_name" => "PubSub Activity",
        "activity_type" => "PERMANENT_REMOVAL",
        "activity_period_start" => "2026-01-01",
        "monitoring_period_start" => "2025-12-01",
        "methodology_ids" => [insert_methodology().id]
      },
      overrides
    )
  end

  # @req: CRCF-21 — developer submissions must be visible to admin within seconds (KR 2.3).
  describe "PubSub broadcasts on \"activities:new\"" do
    test "create_activity/2 broadcasts {:activity_created, activity} on success" do
      Projects.subscribe_activities()
      project = insert_project("PubHost")

      assert {:ok, %{activity: activity}} =
               Projects.create_activity(project.id, activity_params())

      assert_receive {:activity_created, ^activity}, 1_000
    end

    test "create_activity/2 does not broadcast when transaction rolls back" do
      Projects.subscribe_activities()
      project = insert_project("PubRollback")
      project_id = project.id

      assert {:error, _} =
               Projects.create_activity(
                 project.id,
                 activity_params(%{"methodology_ids" => [Ecto.UUID.generate()]})
               )

      refute_receive {:activity_created, %{project_id: ^project_id}}, 200
    end

    test "create_activity/2 does not broadcast on validation failure" do
      Projects.subscribe_activities()
      project = insert_project("PubValidation")
      project_id = project.id
      assert {:error, _} = Projects.create_activity(project.id, %{"activity_name" => ""})
      refute_receive {:activity_created, %{project_id: ^project_id}}, 200
    end
  end
end
