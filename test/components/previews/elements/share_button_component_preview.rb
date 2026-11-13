# frozen_string_literal: true

module Elements
  class ShareButtonComponentPreview < ViewComponent::Preview
    def default
      render ShareButtonComponent.new(url: "https://www.fantasyforecast.co.uk/rankings", title: "FPL rankings",
                                      aria_label: "Share these rankings")
    end

    def labelled
      render ShareButtonComponent.new(label: "Share this squad", url: "https://www.fantasyforecast.co.uk/squad",
                                      title: "The best £100.0m FPL squad")
    end
  end
end
