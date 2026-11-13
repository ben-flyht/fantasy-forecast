# frozen_string_literal: true

class LeaderboardComponent < ViewComponent::Base
  Column = Struct.new(:label, :width)

  renders_many :rows, "LeaderboardRowComponent"

  def initialize(columns:, caption: nil)
    @columns = columns.map { |label, width| Column.new(label, width) }
    @caption = caption
  end

  private

  attr_reader :columns, :caption
end
