module PacksHelper
  def pack_points(points) = format("%.1f", points)

  def pack_card_points(points) = format("%.2f", points)

  def pack_percent(share) = (share * 100).round

  def pack_share(share) = "#{pack_percent(share)}%"

  def pack_sections(weekly:)
    [
      PageHeadingComponent::Horizon.new(label: "This week's pack", url: pack_landing_path, current: weekly),
      PageHeadingComponent::Horizon.new(label: "Practice", url: new_pack_path, current: !weekly)
    ]
  end
end
