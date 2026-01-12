class FormComponent < ViewComponent::Base
  def initialize(scores:)
    @scores = scores || []
  end

  private

  attr_reader :scores

  def opacities
    %w[opacity-100 opacity-100 opacity-100 opacity-100 opacity-100 opacity-80 opacity-60 opacity-40]
  end
end
