# frozen_string_literal: true

module Players
  class RankMovementComponentPreview < ViewComponent::Preview
    def climbing
      render RankMovementComponent.new(history: PreviewFixtures.history(ranks: [ 26, 12 ]))
    end

    def falling
      render RankMovementComponent.new(history: PreviewFixtures.history(ranks: [ 4, 9 ]))
    end

    def steady
      render RankMovementComponent.new(history: PreviewFixtures.history(ranks: [ 9, 9 ]))
    end
  end
end
