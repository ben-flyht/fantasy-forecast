# frozen_string_literal: true

module Layout
  class PanelComponentPreview < ViewComponent::Preview
    # @param tone select { choices: [muted, outline, strong, dark] }
    def playground(tone: :muted)
      render_with_template template: "layout/panel_component_preview/tones", locals: { tones: [ tone.to_sym ] }
    end

    def tones
      render_with_template locals: { tones: PanelComponent::TONES.keys }
    end
  end
end
