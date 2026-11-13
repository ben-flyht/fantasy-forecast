# frozen_string_literal: true

module Players
  class TeamWatermarkComponentPreview < ViewComponent::Preview
    def on_club_colours
      render_with_template locals: { teams: %i[arsenal city liverpool newcastle].map { |key| PreviewFixtures.team(key) } }
    end
  end
end
