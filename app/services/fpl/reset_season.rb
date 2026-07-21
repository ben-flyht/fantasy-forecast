module Fpl
  # Wipes every table that is a local mirror of FPL data, ready for a fresh
  # season to be re-synced. Strategies are deliberately left alone: they hold the
  # tuned scoring config, not season data.
  #
  # Order matters. Each model is deleted before the models it references via a
  # foreign key, so we never trip a constraint mid-wipe.
  class ResetSeason < ApplicationService
    DELETE_ORDER = [ Forecast, Statistic, Performance, Match, Player, Gameweek, Team ].freeze

    def call
      ActiveRecord::Base.transaction do
        DELETE_ORDER.to_h { |model| [ model.table_name, model.delete_all ] }
      end
    end
  end
end
