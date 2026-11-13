# frozen_string_literal: true

class ShareButtonComponent < ViewComponent::Base
  def initialize(label: "Share", url: nil, title: nil, aria_label: nil)
    @label = label
    @url = url
    @title = title
    @aria_label = aria_label
  end

  private

  attr_reader :label, :aria_label

  def url = @url || helpers.meta_url

  def title = @title || helpers.meta_title

  def data
    { controller: "share", share_url_value: url, share_title_value: title,
      action: "share#share click->analytics#track", analytics_event_param: "share_click" }
  end
end
