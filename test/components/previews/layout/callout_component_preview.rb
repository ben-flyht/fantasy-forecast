# frozen_string_literal: true

module Layout
  class CalloutComponentPreview < ViewComponent::Preview
    # @param tone select { choices: [muted, outline, dark] }
    def playground(tone: :muted)
      render_with_template template: "layout/callout_component_preview/tones", locals: { tones: [ tone.to_sym ] }
    end

    def tones
      render_with_template locals: { tones: CalloutComponent::BODY_TONES.keys }
    end

    def plain_title
      render_with_template
    end

    def without_body
      render CalloutComponent.new(eyebrow: "Check your inbox", title: "Your pack is on its way.", tone: :dark)
    end
  end
end
