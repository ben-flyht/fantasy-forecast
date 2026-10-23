module History
  Appearance = Struct.new(:element, :round, :team_id, :kickoff, :minutes, :points, :bonus,
                          :rates, :selected, :value, :transfers_in, :transfers_out, keyword_init: true) do
    def self.from_row(row, fixture)
      new(**identity(row, fixture), **performance(row), **market(row))
    end

    def self.identity(row, fixture)
      home = row["was_home"].to_s.casecmp?("true")
      { element: row["element"].to_i, round: row["round"].to_i,
        team_id: fixture[home ? "team_h" : "team_a"].to_i, kickoff: Time.zone.parse(row["kickoff_time"]) }
    end

    def self.performance(row)
      { minutes: row["minutes"].to_f, points: row["total_points"].to_f, bonus: row["bonus"].to_f,
        rates: Season::RATES.keys.to_h { |stat| [ stat, row[stat].presence&.to_f ] } }
    end

    def self.market(row)
      %w[selected value transfers_in transfers_out].to_h { |field| [ field.to_sym, row[field].to_f ] }
    end
  end
end
