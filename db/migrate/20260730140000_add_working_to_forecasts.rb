# The working behind a forecast: the figures it was multiplied from, stored with
# it. A number nobody can check is only an assertion, and recomputing the
# reasoning later would let the explanation drift from the figure it explains.
#
# Numbers rather than sentences. Wording belongs in a view, where it can be
# changed without rewriting history, and numbers can be asked questions: which
# forecasts were dragged down by a sell-off, did the fixture term ever earn its
# place.
class AddWorkingToForecasts < ActiveRecord::Migration[8.0]
  def change
    add_column :forecasts, :working, :jsonb, default: {}, null: false
  end
end
