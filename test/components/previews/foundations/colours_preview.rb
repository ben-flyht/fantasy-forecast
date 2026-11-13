# frozen_string_literal: true

module Foundations
  class ColoursPreview < ViewComponent::Preview
    Swatch = Struct.new(:name, :token, :swatch, :source, :use)

    GROUPS = {
      "Text" => [
        Swatch.new("Ink", "text-ink", "bg-ink", "zinc-950",
                   "Headings, names and figures. Also the fill of solid buttons, badges and dark panels."),
        Swatch.new("Body", "text-body", "bg-body", "zinc-600", "Running copy and control labels."),
        Swatch.new("Muted", "text-muted", "bg-muted", "zinc-500", "Subtitles, eyebrows and secondary labels."),
        Swatch.new("Faint", "text-faint", "bg-faint", "zinc-400", "The weaker of two figures, icons at rest, footnotes."),
        Swatch.new("Inverse muted", "text-inverse-muted", "bg-inverse-muted", "zinc-300", "Copy on an ink panel.")
      ],
      "Lines" => [
        Swatch.new("Line emphasis", "border-line-emphasis", "bg-line-emphasis", "zinc-400", "A border on hover or focus."),
        Swatch.new("Line strong", "border-line-strong", "bg-line-strong", "zinc-300", "Form controls and dashed drop targets."),
        Swatch.new("Line", "border-line", "bg-line", "zinc-200", "Card, panel and button borders."),
        Swatch.new("Line subtle", "border-line-subtle", "bg-line-subtle", "zinc-100", "Dividers between rows.")
      ],
      "Surfaces" => [
        Swatch.new("Surface", "bg-surface", "bg-surface", "white", "The page and anything standing on it."),
        Swatch.new("Surface subtle", "bg-surface-subtle", "bg-surface-subtle", "zinc-50", "Stat strips, hovered rows, the subject row of a table."),
        Swatch.new("Surface muted", "bg-surface-muted", "bg-surface-muted", "zinc-100", "Muted panels and your own row on a leaderboard.")
      ],
      "Validation" => [
        Swatch.new("Danger", "text-danger", "bg-danger", "red-700", "Form errors only. Never better/worse or up/down."),
        Swatch.new("Danger surface", "bg-danger-surface", "bg-danger-surface", "red-400 at 20%", "The fill behind a form error.")
      ]
    }.freeze

    def palette
      render_with_template locals: { groups: GROUPS }
    end

    def club_colours
      teams = Team::COLORS.keys.sort.map { |short_name| Team.new(short_name: short_name, name: short_name) }
      render_with_template locals: { teams: teams, fallback: Team::DEFAULT_COLOR }
    end
  end
end
