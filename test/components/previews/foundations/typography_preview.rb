# frozen_string_literal: true

module Foundations
  class TypographyPreview < ViewComponent::Preview
    Style = Struct.new(:name, :token, :spec, :use, :sample)

    SCALE = [
      Style.new("Display", "text-display", "30px / 1 · 800 · -0.03em",
                "The one name or number a panel exists to say.", "7.4"),
      Style.new("Headline", "text-headline", "24px / 1 · 800 · -0.03em",
                "Callout titles.", "Your pack is on its way."),
      Style.new("Title", "text-title", "20–24px / 1.3 · 600 · -0.015em",
                "The page title. One per page.", "Who to Captain in FPL Gameweek 12"),
      Style.new("Heading", "text-heading", "18px / 28px · 600",
                "Section headings.", "The best players in Gameweek 12"),
      Style.new("Subheading", "text-subheading", "16px / 24px · 600",
                "Empty states and prompts.", "No squad yet"),
      Style.new("Figure", "text-figure", "18px / 1 · 800 · -0.02em",
                "Stat values, leaderboard places and points.", "£99.5m"),
      Style.new("Copy", "text-copy", "14px / 24px · 400",
                "Running paragraphs.", "Every player is forecast for the coming gameweek and for the rest of the season."),
      Style.new("Interface", "text-sm", "14px / 20px",
                "Controls, tables and subtitles.", "Check the forecast before you pick your team."),
      Style.new("Fine print", "text-xs", "12px / 16px",
                "Help text, captions and footers.", "Not affiliated with the Premier League."),
      Style.new("Eyebrow", "eyebrow", "10px · 700 · uppercase · wide",
                "The label above a value, and table headers.", "Expected points")
    ].freeze

    WEIGHTS = [
      [ "font-normal", "400", "Copy" ],
      [ "font-medium", "500", "Controls and links" ],
      [ "font-semibold", "600", "Headings" ],
      [ "font-bold", "700", "Eyebrows and card details" ],
      [ "font-extrabold", "800", "The logo, figures and player names" ]
    ].freeze

    def scale
      render_with_template locals: { styles: SCALE }
    end

    def weights
      render_with_template locals: { weights: WEIGHTS }
    end

    def links
      render_with_template
    end
  end
end
