# Derives the five diagnostic ranking concepts (quality, form, minutes, schedule,
# differential) and tiers each one within the position, reusing the same
# percentage-from-top scale as the Overall tier (TierCalculator).
#
# This is a read-only presentation layer: it does not affect the Overall ranking
# order, only adds per-concept weather tiers (and a one-directional "gem" flag)
# to help Draft managers read the wire.
#
# Inputs are passed in so the service stays pure and fast to test:
#   rankings           - Array of ConsensusRanking::Ranking (player_id, score, position, team_id)
#   stats              - { player_id => { stat_type => Float } } latest snapshot values
#   difficulty_by_team - { team_id => Float } average upcoming FDR (1 easy .. 5 hard)
class ConceptTiers
  CONCEPTS = %i[quality form minutes schedule differential].freeze

  # Snapshot statistic types the concepts read. The controller loads exactly these.
  STAT_TYPES = %w[
    expected_goals_per_90 expected_goal_involvements_per_90 clean_sheets_per_90
    saves_per_90 defensive_contribution_per_90 starts_per_90
    penalties_order corners_freekicks_order direct_freekicks_order
    form selected_by_percent
  ].freeze

  # A player is flagged a gem when we rate them highly but the wider FPL crowd
  # has largely overlooked them. One-directional: popular players are never
  # penalised, they simply do not earn the tag.
  GEM_MIN_STRENGTH = 0.5   # our score is at least half the position's best
  GEM_MAX_OWNERSHIP = 15.0 # owned by fewer than 15% of FPL managers

  def initialize(rankings, stats:, difficulty_by_team:)
    @rankings = rankings
    @stats = stats
    @difficulty_by_team = difficulty_by_team
    @top_overall = positive_max(@rankings.map(&:score))
  end

  # => { player_id => { quality:, form:, minutes:, schedule:, differential:, gem: } }
  def call
    raw = raw_scores_by_concept
    tops = raw.transform_values { |by_player| positive_max(by_player.values) }

    @rankings.each_with_object({}) do |ranking, result|
      result[ranking.player_id] = tiers_for(ranking, raw, tops)
    end
  end

  private

  def tiers_for(ranking, raw, tops)
    tiers = CONCEPTS.index_with { |concept| tier_for(raw[concept][ranking.player_id], tops[concept]) }
    tiers[:gem] = gem?(ranking)
    tiers
  end

  def raw_scores_by_concept
    CONCEPTS.index_with do |concept|
      @rankings.each_with_object({}) do |ranking, scores|
        scores[ranking.player_id] = send("#{concept}_raw", ranking)
      end
    end
  end

  def tier_for(score, top_score)
    return 5 if score.nil? || top_score.nil? || top_score.zero?

    percentage = TierCalculator.percentage_from_top(score, top_score)
    TierCalculator.tier_number_from_percentage(percentage)
  end

  # Underlying quality as a per-90 rate, weighted by what matters for the position.
  # Set-piece duty (penalty/corner/free-kick first choice) nudges it up.
  def quality_raw(ranking)
    position_quality(ranking) + set_piece_bonus(ranking)
  end

  def position_quality(ranking)
    case ranking.position
    when "goalkeeper" then stat(ranking, "saves_per_90") + (stat(ranking, "clean_sheets_per_90") * 2)
    when "defender"   then defender_quality(ranking)
    when "midfielder" then stat(ranking, "expected_goal_involvements_per_90") + (stat(ranking, "defensive_contribution_per_90") * 0.05)
    else stat(ranking, "expected_goals_per_90") + (stat(ranking, "expected_goal_involvements_per_90") * 0.5)
    end
  end

  def defender_quality(ranking)
    (stat(ranking, "clean_sheets_per_90") * 3) +
      (stat(ranking, "defensive_contribution_per_90") * 0.1) +
      stat(ranking, "expected_goal_involvements_per_90")
  end

  def set_piece_bonus(ranking)
    bonus = 0.0
    bonus += 0.15 if stat(ranking, "penalties_order") == 1.0
    bonus += 0.05 if stat(ranking, "corners_freekicks_order") == 1.0 || stat(ranking, "direct_freekicks_order") == 1.0
    bonus
  end

  # FPL's own form scalar (recent points per game).
  def form_raw(ranking)
    stat(ranking, "form")
  end

  # Minutes security: how reliably the player starts.
  def minutes_raw(ranking)
    stat(ranking, "starts_per_90")
  end

  # Easier upcoming fixtures score higher (invert the 1-5 FDR). No fixture => nil.
  def schedule_raw(ranking)
    difficulty = @difficulty_by_team[ranking.team_id]
    return nil if difficulty.nil?

    6 - difficulty
  end

  # One-directional differential: strong where we rate the player highly but
  # ownership is low. Popular players tend towards zero, never negative.
  def differential_raw(ranking)
    our_strength(ranking) * (1 - (ownership(ranking) / 100.0))
  end

  def gem?(ranking)
    our_strength(ranking) >= GEM_MIN_STRENGTH && ownership(ranking) < GEM_MAX_OWNERSHIP && ownership(ranking).positive?
  end

  def our_strength(ranking)
    return 0.0 if @top_overall.nil? || @top_overall.zero? || ranking.score.nil?

    [ ranking.score.to_f / @top_overall, 1.0 ].min
  end

  def ownership(ranking)
    stat(ranking, "selected_by_percent")
  end

  def stat(ranking, type)
    @stats.dig(ranking.player_id, type) || 0.0
  end

  def positive_max(values)
    values.compact.select(&:positive?).max
  end
end
