# frozen_string_literal: true

module Players
  class PlayerListComponentPreview < ViewComponent::Preview
    def rankings
      render PlayerListComponent.new(entries: PreviewFixtures.entries)
    end

    def squad
      entries = [
        PreviewFixtures.entry(:pope, grade: "C", leading: "GK"),
        PreviewFixtures.entry(:gabriel, grade: "B", leading: "DF"),
        PreviewFixtures.entry(:saka, grade: "A", leading: "MF"),
        PreviewFixtures.entry(:haaland, grade: "A", leading: "FW", captain: true)
      ]
      render PlayerListComponent.new(entries: entries, leading_label: "Pos")
    end
  end
end
