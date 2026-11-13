# frozen_string_literal: true

class ProseComponent < ViewComponent::Base
  def call
    tag.div(content, class: "prose")
  end
end
