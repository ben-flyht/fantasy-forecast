module History
  module Engines
    def self.calibrated(factor)
      Class.new(ExpectedPoints) do
        define_method(:calibrated) { |per_90| ExpectedPoints::APPEARANCE + factor * (per_90 - ExpectedPoints::APPEARANCE) }
        private :calibrated
      end
    end
  end
end
