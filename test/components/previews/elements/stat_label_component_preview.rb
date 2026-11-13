# frozen_string_literal: true

module Elements
  class StatLabelComponentPreview < ViewComponent::Preview
    def with_definition
      render StatLabelComponent.new(term: StatGlossary.fetch(:expected_goals_per_90))
    end

    def plain
      render StatLabelComponent.new(term: StatGlossary.fetch(:minutes))
    end
  end
end
