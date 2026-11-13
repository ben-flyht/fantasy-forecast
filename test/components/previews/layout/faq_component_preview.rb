# frozen_string_literal: true

module Layout
  class FaqComponentPreview < ViewComponent::Preview
    def default
      render FaqComponent.new(title: "FPL Captain FAQ", pairs: [
        [ "Who should I captain this week in FPL?",
          "Our pick for Gameweek 12 is Haaland of Man City, at home to Fulham. We forecast 7.4 points before the armband doubles them." ],
        [ "How often does the captain pick change?",
          "The forecast behind it is rewritten every hour, so the pick can move right up to the deadline." ],
        [ "Can I captain a player on my bench?",
          "No. FPL only doubles the score of a captain in your starting eleven." ]
      ])
    end
  end
end
