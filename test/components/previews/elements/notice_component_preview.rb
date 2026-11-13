# frozen_string_literal: true

module Elements
  class NoticeComponentPreview < ViewComponent::Preview
    def info
      render NoticeComponent.new(message: "Profile saved.")
    end

    def player_news
      render NoticeComponent.new(message: "Hamstring injury - 75% chance of playing")
    end

    def alert
      render NoticeComponent.new(message: "That link has expired. Enter your email for a new one.", tone: :alert)
    end
  end
end
