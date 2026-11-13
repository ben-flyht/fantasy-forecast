# frozen_string_literal: true

module Play
  class PackPiecesPreview < ViewComponent::Preview
    def sealed_pack
      render_with_template locals: { small: false }
    end

    def small_sealed_pack
      render_with_template template: "play/pack_pieces_preview/sealed_pack", locals: { small: true }
    end

    def pick_verdicts
      render_with_template
    end

    def forfeit
      render_with_template
    end
  end
end
