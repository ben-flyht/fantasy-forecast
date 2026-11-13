# frozen_string_literal: true

module Elements
  class FieldComponentPreview < ViewComponent::Preview
    def default
      render FieldComponent.new(name: :first_name, label: "First name", value: "Sam")
    end

    def with_help
      render FieldComponent.new(name: :username, label: "Username", placeholder: "e.g. Haaland's Hairband",
                                help: "This is what the leaderboards show. Up to 20 characters.")
    end

    def with_error
      render FieldComponent.new(name: :username, label: "Username", value: "12",
                                error: "Username needs a letter.", help: "This is what the leaderboards show.")
    end

    def with_action
      render_with_template
    end
  end
end
