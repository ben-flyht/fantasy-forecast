class PackEntry < ApplicationRecord
  belongs_to :manager
  belongs_to :weekly_pack

  validates :manager_id, uniqueness: { scope: :weekly_pack_id }
  validates :hand, format: { with: /\A[abx]*\z/ }
  validate :within_the_pack
  validate :before_the_deadline, if: :hand_changed?

  def pack_hand
    code = weekly_pack.locked? ? hand.ljust(weekly_pack.pack.size, PackHand::FORFEIT) : hand
    PackHand.parse(weekly_pack.pack, code)
  end

  def complete? = pack_hand&.complete?

  def pick(choice)
    return false if complete? || !PackHand::FORMAT.match?(choice.to_s) || choice.to_s.size != 1

    self.hand = hand.to_s + choice
    save
  end

  private

  def within_the_pack
    errors.add(:hand, "is longer than the pack") if weekly_pack && hand.to_s.size > weekly_pack.pack.size
  end

  def before_the_deadline
    errors.add(:base, "The deadline has passed.") if weekly_pack&.locked?
  end
end
