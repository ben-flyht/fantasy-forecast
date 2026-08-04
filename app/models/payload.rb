# Everything FPL sends us, kept exactly as they sent it.
#
# Statistics holds our own curated numbers: the handful of readings the ranking
# takes, cast to a decimal, one row each. That is the wrong shape for the rest of
# a player's record. FPL also sends text (injury news and its return date), dates
# (when a player signed), categories (fit, doubtful, injured, suspended), arrays,
# and nulls. A decimal column cannot tell "no reading" from "a reading of nought",
# a distinction that has caught us out more than once.
#
# Nothing scores off this. It is the source, kept so that the day a strategy wants
# a field nobody thought to map, its history is already here rather than starting
# from the day we noticed. Projecting it into statistics after the fact costs a
# query; going back to FPL for a season of it is not possible at all.
#
# A season of it, and only a season: every payload hangs off a gameweek, so the
# summer wipe takes the archive with it. Keeping one across a rollover means
# giving payloads a season of their own to belong to. See Fpl::ResetSeason.
class Payload < ApplicationRecord
  ELEMENT = "element".freeze # a player
  TEAM = "team".freeze
  EVENT = "event".freeze     # a gameweek
  FIXTURE = "fixture".freeze

  KINDS = [ ELEMENT, TEAM, EVENT, FIXTURE ].freeze

  belongs_to :gameweek

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :fpl_id, presence: true, uniqueness: { scope: [ :kind, :gameweek_id ] }

  scope :elements, -> { where(kind: ELEMENT) }
  scope :teams, -> { where(kind: TEAM) }
  scope :events, -> { where(kind: EVENT) }
  scope :fixtures, -> { where(kind: FIXTURE) }
  scope :of_kind, ->(kind) { where(kind: kind) }
  scope :for_gameweek, ->(gameweek) { where(gameweek: gameweek) }

  # One field across a whole set, as { fpl_id => value }, read straight out of the
  # payload by Postgres so the rows themselves never come back over the wire.
  #
  #   Payload.elements.for_gameweek(gameweek).values_of("status")
  def self.values_of(field)
    pluck(:fpl_id, Arel.sql("data ->> #{connection.quote(field)}")).to_h
  end
end
