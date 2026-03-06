class FormComponent < ViewComponent::Base
  include ApplicationHelper

  def initialize(scores:, draft_category: nil)
    @scores = scores || []
    @draft_category = draft_category
  end

  private

  attr_reader :scores

  def opacities
    %w[opacity-100 opacity-100 opacity-100 opacity-100 opacity-100 opacity-80 opacity-60 opacity-40]
  end
end
