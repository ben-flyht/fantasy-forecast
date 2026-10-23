module PacksHelper
  def pack_sections(weekly:)
    [
      PageHeadingComponent::Horizon.new(label: "This week's pack", url: pack_landing_path, current: weekly),
      PageHeadingComponent::Horizon.new(label: "Practice", url: new_pack_path, current: !weekly)
    ]
  end
end
