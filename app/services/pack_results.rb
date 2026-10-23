class PackResults < ApplicationService
  def call
    pending.find_each { |entry| send_results(entry) }
    true
  end

  private

  def pending
    PackEntry.where(results_sent_at: nil)
             .joins(weekly_pack: :gameweek).where(gameweeks: { is_finished: true })
             .includes(:manager, weekly_pack: :gameweek)
  end

  def send_results(entry)
    record(entry)
    PackMailer.with(entry: entry, standing: standing(entry), next_gameweek: Gameweek.next_gameweek).results.deliver_now
    entry.update!(results_sent_at: Time.current)
  rescue StandardError => error
    Rails.logger.error "Pack results for entry #{entry.id} failed: #{error.message}"
  end

  def record(entry)
    marks = marks_for(entry.weekly_pack)
    entry.update!(real_points: marks[:real].for(entry.pack_hand).points,
                  accuracy: marks[:accuracy].of(entry.pack_hand),
                  forecast_accuracy: marks[:accuracy].of(marks[:forecast]))
  end

  def standing(entry)
    managers = marks_for(entry.weekly_pack)[:board].rows.reject(&:forecast?).map(&:manager_id)
    { place: managers.index(entry.manager_id).to_i + 1, of: managers.size }
  end

  def marks_for(weekly)
    @marks ||= {}
    @marks[weekly.id] ||= begin
      real = PackRealScore.new(weekly.gameweek)
      { real: real, accuracy: PackAccuracy.new(weekly.pack, real), forecast: PackScore.new(weekly.pack).forecast,
        board: PackLeaderboard.new(weekly) }
    end
  end
end
