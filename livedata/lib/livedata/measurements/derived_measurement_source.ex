defmodule Livedata.Measurements.DerivedMeasurementSource do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @foreign_key_type :binary_id

  schema "derived_measurement_sources" do
    # @req: CRCF-24
    field :derived_id, :binary_id, primary_key: true
    # @req: CRCF-33
    field :source_id, :binary_id, primary_key: true
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, [:derived_id, :source_id])
    |> validate_required([:derived_id, :source_id])
    |> foreign_key_constraint(:derived_id)
    |> unique_constraint(:source_id,
      name: :derived_measurement_sources_source_id_index,
      message: "has already been used as a source"
    )
  end
end
