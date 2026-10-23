class PickablePool < ApplicationService
  Candidate = Data.define(:player, :rank, :cost, :expected_points) do
    def player_id = player.id
    def position = player.position
    def team_id = player.team_id
  end

  def initialize(gameweek:, horizon: "gameweek")
    @gameweek = gameweek
    @horizon = horizon
  end

  def call
    Forecast.where(gameweek: gameweek, horizon: horizon)
            .includes(player: :team)
            .filter_map { |forecast| candidate(forecast) }
  end

  private

  attr_reader :gameweek, :horizon

  def candidate(forecast)
    player = forecast.player
    return unless pickable?(player, forecast)

    cost = costs.dig(player.id, "now_cost")
    return if cost.nil? || cost.zero?

    Candidate.new(player: player, rank: forecast.rank, cost: cost.to_i, expected_points: forecast.score.to_f)
  end

  def pickable?(player, forecast)
    return false if player.nil? || player.departed || !player.selectable
    return false if player.status.present? && player.status != "a"

    forecast.score.present?
  end

  def costs
    @costs ||= Statistic.where(type: "now_cost").latest_by_player
  end
end
