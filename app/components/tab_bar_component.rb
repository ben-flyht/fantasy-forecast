# frozen_string_literal: true

class TabBarComponent < ViewComponent::Base
  ICONS = {
    rankings: '<path d="M9 6h11M9 12h11M9 18h11M4 6h.01M4 12h.01M4 18h.01"/>',
    compare: '<path d="M4 8h16m-3-3 3 3-3 3M20 16H4m3-3-3 3 3 3"/>',
    squad: '<circle cx="12" cy="5" r="2"/><circle cx="6" cy="12" r="2"/><circle cx="18" cy="12" r="2"/>' \
           '<circle cx="9" cy="19" r="2"/><circle cx="15" cy="19" r="2"/>',
    captain: '<circle cx="12" cy="12" r="9"/><path d="M15 9.5a4 4 0 1 0 0 5"/>',
    play: '<rect x="4" y="6" width="11" height="15" rx="2"/>' \
          '<path d="M9 6V5a2 2 0 0 1 2-2h7a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2h-3"/>'
  }.freeze

  def initialize(links:)
    @links = links
  end

  private

  attr_reader :links

  def icon(name) = ICONS.fetch(name).html_safe

  def link_classes(current)
    "flex flex-col items-center gap-1 py-2 text-xs #{current ? 'font-medium text-ink' : 'text-muted hover:text-ink'}"
  end
end
