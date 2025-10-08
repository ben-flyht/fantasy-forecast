module ApplicationHelper
  def meta_title
    content_for?(:meta_title) ? content_for(:meta_title) : "Fantasy Forecast - FPL Player Rankings & Consensus"
  end

  def meta_description
    content_for?(:meta_description) ? content_for(:meta_description) : "Crowd-sourced Fantasy Premier League player rankings updated every gameweek. Make better FPL transfer and captain decisions with consensus rankings from experienced managers."
  end

  def meta_image
    content_for?(:meta_image) ? content_for(:meta_image) : image_url("og-image.png")
  end

  def meta_url
    content_for?(:meta_url) ? content_for(:meta_url) : request.original_url
  end
end
