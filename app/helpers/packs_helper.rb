module PacksHelper
  HIDDEN_GRADE = "?".freeze

  def pack_card_arguments(card, href: nil, revealed: false, captain: false)
    {
      ranking: pack_card_ranking(card, revealed: revealed),
      player: card.player,
      facts: { "now_cost" => card.cost },
      leading: position_letter(card.position),
      captain: captain,
      href: href
    }
  end

  def pack_card_ranking(card, revealed:)
    ConsensusRanking::Ranking.new(
      player_id: card.player_id, position: card.position, bot_rank: card.rank, score: card.expected_points,
      grade: revealed ? TierCalculator.grade_from_points(card.expected_points) : HIDDEN_GRADE
    )
  end

  def pack_points(points) = format("%.1f", points)

  def pack_card_points(points) = format("%.2f", points)

  def pack_share(share) = "#{(share * 100).round}%"
end
