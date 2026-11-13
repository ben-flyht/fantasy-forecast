# frozen_string_literal: true

module Elements
  class SegmentedControlComponentPreview < ViewComponent::Preview
    def horizons
      render SegmentedControlComponent.new(label: "Forecast horizon", options: options(
        [ "Gameweek 12", "GW12" ], [ "Next 5 gameweeks", "Next 5" ], [ "Rest of season", "Season" ]
      ))
    end

    def positions
      render SegmentedControlComponent.new(label: "Position", options: options(
        %w[Goalkeepers GK], %w[Defenders DEF], %w[Midfielders MID], %w[Forwards FWD], current: 2
      ))
    end

    private

    def options(*labels, current: 0)
      labels.each_with_index.map do |(label, short), index|
        SegmentedControlComponent::Option.new(label: label, short_label: short, url: "#", current: index == current,
                                              value: label.parameterize)
      end
    end
  end
end
