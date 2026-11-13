# frozen_string_literal: true

module Foundations
  class SpacingPreview < ViewComponent::Preview
    Step = Struct.new(:name, :token, :size, :bar, :use)

    RHYTHM = [
      Step.new("Section", "mt-section", "40px", "w-section", "Between one section of a page and the next."),
      Step.new("Group", "mt-group", "24px", "w-group", "Between a page heading and its content, and between blocks in a section."),
      Step.new("Panel", "p-panel", "20px", "w-panel", "The padding inside a panel or callout."),
      Step.new("Stack", "mt-stack", "12px", "w-stack", "Between a section heading and what it introduces.")
    ].freeze

    RADII = [
      [ "Badge", "rounded-badge", "4px", "Badges and icon buttons." ],
      [ "Control", "rounded-control", "8px", "Buttons, inputs, notices and menus." ],
      [ "Card", "rounded-card", "12px", "Player cards, panels, callouts and tables." ],
      [ "Full", "rounded-full", "∞", "Avatars and verdict marks." ]
    ].freeze

    def rhythm
      render_with_template locals: { steps: RHYTHM }
    end

    def in_context
      render_with_template
    end

    def radius
      render_with_template locals: { radii: RADII }
    end
  end
end
