# frozen_string_literal: true

module Layout
  class PageHeadingComponentPreview < ViewComponent::Preview
    def title_only
      render PageHeadingComponent.new(title: "FPL Rankings and Predictions for Gameweek 12",
                                      subtitle: "Check the forecast before you pick your team.")
    end

    def with_back_and_share
      render PageHeadingComponent.new(title: "Who to Captain in FPL Gameweek 12",
                                      subtitle: "The armband doubles his score, so it belongs on the highest forecast in the game.",
                                      updated_at: 25.minutes.ago, share: "Share this captain pick", back: back)
    end

    def with_horizons
      render PageHeadingComponent.new(title: "Best FPL Midfielders, Gameweek 12",
                                      subtitle: "Check the forecast before you pick your team.",
                                      updated_at: 25.minutes.ago, share: "Share these rankings", back: back,
                                      horizons: horizons)
    end

    def with_aside
      render_with_template locals: { horizons: horizons }
    end

    private

    def back = PageHeadingComponent::Back.new(label: "Back to Home", url: "#")

    def horizons
      [ [ "Gameweek 12", "GW12" ], [ "Next 5 gameweeks", "Next 5" ], [ "Rest of season", "Season" ] ]
        .each_with_index.map do |(label, short), index|
          PageHeadingComponent::Horizon.new(label: label, short_label: short, url: "#", current: index.zero?,
                                            value: label.parameterize)
        end
    end
  end
end
