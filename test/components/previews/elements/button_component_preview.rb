# frozen_string_literal: true

module Elements
  class ButtonComponentPreview < ViewComponent::Preview
    # @param label text
    # @param variant select { choices: [outline, solid, inverse, ghost] }
    # @param size select { choices: [sm, md] }
    def playground(label: "All rankings", variant: :outline, size: :sm)
      render_with_template template: "elements/button_component_preview/variants",
                           locals: { variants: [ variant.to_sym ], sizes: [ size.to_sym ], label: label }
    end

    def variants
      render_with_template locals: { variants: ButtonComponent::VARIANTS.keys, sizes: %i[sm md], label: "Email me my pack" }
    end

    def link
      render ButtonComponent.new(label: "See the squad", href: "#")
    end

    def disabled
      render ButtonComponent.new(label: "Open pack", variant: :solid, size: :md, disabled: true)
    end

    def icon_only
      render_with_template
    end

    def beside_a_field
      render_with_template
    end
  end
end
