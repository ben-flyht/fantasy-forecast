# frozen_string_literal: true

module Elements
  class DropdownComponentPreview < ViewComponent::Preview
    def default
      render_with_template locals: { selected: "" }
    end

    def with_selection
      render_with_template template: "elements/dropdown_component_preview/default", locals: { selected: 2 }
    end
  end
end
