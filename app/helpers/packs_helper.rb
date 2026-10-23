module PacksHelper
  def pack_sections(weekly:)
    [
      PageHeadingComponent::Horizon.new(label: "Beat the algorithm", url: pack_landing_path, current: weekly),
      PageHeadingComponent::Horizon.new(label: "Practice", url: practice_pack_path, current: !weekly)
    ]
  end
end
