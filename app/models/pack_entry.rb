class PackEntry < ApplicationRecord
  belongs_to :manager
  belongs_to :weekly_pack

  validates :manager_id, uniqueness: { scope: :weekly_pack_id }
  validate :hand_is_complete
  validate :before_the_deadline, on: :create

  def pack_hand
    @pack_hand ||= PackHand.parse(weekly_pack.pack, hand)
  end

  private

  def hand_is_complete
    errors.add(:hand, "is not a finished pack") unless weekly_pack && pack_hand&.complete?
  end

  def before_the_deadline
    errors.add(:base, "The deadline has passed.") if weekly_pack&.locked?
  end
end
