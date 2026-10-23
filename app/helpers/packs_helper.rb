module PacksHelper
  def pack_points(points) = format("%.1f", points)

  def pack_card_points(points) = format("%.2f", points)

  def pack_percent(share) = (share * 100).round

  def pack_share(share) = "#{pack_percent(share)}%"
end
