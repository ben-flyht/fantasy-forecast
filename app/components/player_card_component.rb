# frozen_string_literal: true

class PlayerCardComponent < ViewComponent::Base
  def initialize(player: nil, show_position: false, explanation: nil)
    @player = player
    @show_position = show_position
    @explanation = explanation
  end
end
