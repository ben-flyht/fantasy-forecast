class PackEntry < ApplicationRecord
  belongs_to :manager
  belongs_to :weekly_pack

  validates :hand, presence: true
  validates :manager_id, uniqueness: { scope: :weekly_pack_id }
  validate :hand_is_complete

  def pack_hand
    @pack_hand ||= PackHand.parse(weekly_pack.pack, hand)
  end

  private

  def hand_is_complete
    errors.add(:hand, "is not a finished pack") unless weekly_pack && pack_hand&.complete?
  end
end
