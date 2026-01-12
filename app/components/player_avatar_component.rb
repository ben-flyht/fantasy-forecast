# frozen_string_literal: true

class PlayerAvatarComponent < ViewComponent::Base
  def initialize(player:, size: :medium)
    @player = player
    @size = size
  end

  def size_classes
    case @size
    when :small then "size-10"
    when :medium then "size-10 sm:size-12"
    when :large then "size-20"
    else "size-10 sm:size-12"
    end
  end

  def photo_url
    @player.photo_url
  end
end
