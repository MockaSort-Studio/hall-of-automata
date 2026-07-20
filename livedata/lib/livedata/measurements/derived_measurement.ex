defmodule Livedata.Measurements.DerivedMeasurement do
  use Ecto.Schema
  import Ecto.Changeset

  # @req: CRCF-19
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "derived_measurements" do
    # @req: CRCF-21, CRCF-23
    field :activity_id, :binary_id
    # @req: CRCF-33
    field :computation_id, :binary_id
    field :type, :string
    # @req: CRCF-07, CRCF-27
    field :values, :map
    # @req: CRCF-26
    field :is_superseded, :boolean, default: false
    # @req: CRCF-26
    field :superseded_by, :binary_id
    # @req: CRCF-20
    timestamps(updated_at: false, type: :utc_datetime_usec)
  end

  @doc false
  def changeset(derived_measurement, activity_id, attrs) do
    derived_measurement
    |> cast(attrs, [
      :computation_id,
      :type,
      :values,
      :is_superseded,
      :superseded_by
    ])
    |> put_change(:activity_id, activity_id)
    |> validate_required([
      :activity_id,
      :computation_id,
      :type,
      :values
    ])
    |> validate_supersession()
    |> foreign_key_constraint(:activity_id)
    |> foreign_key_constraint(:superseded_by)
  end

  defp validate_supersession(changeset) do
    is_superseded = get_field(changeset, :is_superseded)
    superseded_by = get_field(changeset, :superseded_by)
    current_id = get_field(changeset, :id)

    changeset
    |> then(fn cs ->
      if is_superseded && is_nil(superseded_by) do
        add_error(cs, :superseded_by, "must be set when is_superseded is true")
      else
        cs
      end
    end)
    |> then(fn cs ->
      if !is_nil(superseded_by) && superseded_by == current_id do
        add_error(cs, :superseded_by, "cannot reference itself")
      else
        cs
      end
    end)
  end
end
