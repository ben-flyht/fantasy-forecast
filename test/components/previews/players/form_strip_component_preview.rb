# frozen_string_literal: true

module Players
  class FormStripComponentPreview < ViewComponent::Preview
    def mixed
      render_with_template template: "players/form_strip_component_preview/strip", locals: { points: [ 6, 13, 8, 2, 2 ] }
    end

    def all_blanks
      render_with_template template: "players/form_strip_component_preview/strip", locals: { points: [ 2, 1, 2, 0, 2 ] }
    end

    def big_haul
      render_with_template template: "players/form_strip_component_preview/strip", locals: { points: [ 2, 21, 5, 9, 12 ] }
    end

    def did_not_play
      render_with_template template: "players/form_strip_component_preview/strip", locals: { points: [ 7, nil, 6 ] }
    end

    def empty
      render_with_template template: "players/form_strip_component_preview/strip", locals: { points: [] }
    end
  end
end
