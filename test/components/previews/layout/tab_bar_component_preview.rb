# frozen_string_literal: true

module Layout
  class TabBarComponentPreview < ViewComponent::Preview
    TABS = [
      [ "Rankings", :rankings ], [ "Compare", :compare ], [ "Squad", :squad ], [ "Captain", :captain ], [ "Play", :play ]
    ].freeze

    # @param current select { choices: [Rankings, Compare, Squad, Captain, Play] }
    def default(current: "Rankings")
      render_with_template locals: { links: links(current) }
    end

    def nothing_current
      render_with_template template: "layout/tab_bar_component_preview/default", locals: { links: links(nil) }
    end

    private

    def links(current)
      TABS.map { |label, icon| [ label, "#", label == current, icon ] }
    end
  end
end
