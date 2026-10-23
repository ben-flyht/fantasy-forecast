module History
  module Engines
    def self.calibrated(factor)
      Class.new(ExpectedPoints) do
        define_method(:calibrated) { |per_90| ExpectedPoints::APPEARANCE + factor * (per_90 - ExpectedPoints::APPEARANCE) }
        private :calibrated
      end
    end

    class SplitFixtures < ExpectedPoints
      private

      def swing(step, fixture)
        return 1.0 if fixture.nil?

        attack, defence = difficulty_of(fixture)
        step**(AVERAGE_DIFFICULTY - (step == ATTACK_STEP ? attack : defence))
      end

      def difficulty_of(fixture)
        default = fixture[:difficulty] || AVERAGE_DIFFICULTY
        [ fixture[:attack] || default, fixture[:defence] || default ]
      end
    end
  end
end
