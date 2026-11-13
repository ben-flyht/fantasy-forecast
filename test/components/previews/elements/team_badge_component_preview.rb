# frozen_string_literal: true

module Elements
  class TeamBadgeComponentPreview < ViewComponent::Preview
    def default
      render TeamBadgeComponent.new(team: PreviewFixtures.team(:arsenal))
    end

    def large
      render TeamBadgeComponent.new(team: PreviewFixtures.team(:city), size: 48)
    end
  end
end
