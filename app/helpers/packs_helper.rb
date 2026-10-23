module PacksHelper
  def pack_sections(current:)
    [
      PageHeadingComponent::Horizon.new(label: "Play", url: pack_landing_path, current: current == :play),
      PageHeadingComponent::Horizon.new(label: "Practice", url: practice_pack_path, current: current == :practice)
    ]
  end
end
