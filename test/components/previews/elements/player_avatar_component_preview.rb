# frozen_string_literal: true

module Elements
  class PlayerAvatarComponentPreview < ViewComponent::Preview
    # @param size select { choices: [small, medium, large] }
    def default(size: :large)
      render PlayerAvatarComponent.new(player: PreviewFixtures.player(:saka), size: size.to_sym)
    end

    def without_photo
      render PlayerAvatarComponent.new(player: PreviewFixtures.player(:unknown), size: :large)
    end
  end
end
