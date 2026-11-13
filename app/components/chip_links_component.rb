# frozen_string_literal: true

class ChipLinksComponent < ViewComponent::Base
  def initialize(links:, label: nil)
    @links = links
    @label = label
  end

  def render? = @links.present?

  def call
    content_tag(@label ? :nav : :div, list, "aria-label": @label)
  end

  private

  def list
    tag.ul(class: "flex flex-wrap gap-2") do
      safe_join(@links.map { |label, url| tag.li(render(ButtonComponent.new(label: label, href: url))) })
    end
  end
end
