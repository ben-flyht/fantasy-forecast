# frozen_string_literal: true

class PlayerCardComponent < ViewComponent::Base
  def initialize(player: nil, show_position: false, selection_url: nil)
    @player = player
    @show_position = show_position
    @selection_url = selection_url
  end
end
