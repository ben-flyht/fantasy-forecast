# frozen_string_literal: true

module Players
  class SeasonRecordComponentPreview < ViewComponent::Preview
    def default
      render SeasonRecordComponent.new(history: PreviewFixtures.history)
    end

    def price_unchanged
      render SeasonRecordComponent.new(history: PreviewFixtures.history(price: [ 145, 145 ]))
    end
  end
end
