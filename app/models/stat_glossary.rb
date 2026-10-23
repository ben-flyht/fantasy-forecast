module StatGlossary
  Term = Struct.new(:label, :definition, keyword_init: true) do
    def defined?
      definition.present?
    end
  end

  TERMS = {
    form: Term.new(label: "Form", definition: "His average points per match over the last 30 days."),
    points: Term.new(label: "Total points"),
    points_per_90: Term.new(label: "Points per 90", definition: "Points scored for every 90 minutes on the pitch."),
    minutes: Term.new(label: "Minutes"),
    starts: Term.new(label: "Starts"),
    goals: Term.new(label: "Goals"),
    goals_per_90: Term.new(label: "Goals per 90"),
    assists: Term.new(label: "Assists"),
    expected_goals_per_90: Term.new(
      label: "xG per 90",
      definition: "Expected goals: how many goals his chances would usually produce, per 90 minutes."
    ),
    expected_assists_per_90: Term.new(
      label: "xA per 90",
      definition: "Expected assists: how many assists his passes would usually produce, per 90 minutes."
    ),
    penalties: Term.new(
      label: "Penalties",
      definition: "Where he stands in his club's order for taking penalties. 1st is the regular taker."
    ),
    clean_sheets_per_90: Term.new(
      label: "Clean sheets per 90",
      definition: "Worth 4 points to keepers and defenders and 1 to midfielders."
    ),
    expected_goals_conceded_per_90: Term.new(
      label: "xGC per 90",
      definition: "Expected goals conceded: how many goals his side would usually let in while he is on the " \
                  "pitch, per 90 minutes. The forecast prices clean sheets from it."
    ),
    saves_per_90: Term.new(label: "Saves per 90", definition: "A point for every 3 saves."),
    defensive_contribution_per_90: Term.new(
      label: "Defensive actions per 90",
      definition: "Clearances, blocks, interceptions, tackles and recoveries. 2 points for 10 in a match for " \
                  "defenders, 12 for midfielders and forwards."
    ),
    bonus: Term.new(label: "Bonus", definition: "Up to 3 points a match for the best performers on the day."),
    yellow_cards: Term.new(label: "Yellow cards"),
    red_cards: Term.new(label: "Red cards")
  }.freeze

  def self.fetch(key)
    TERMS.fetch(key)
  end
end
