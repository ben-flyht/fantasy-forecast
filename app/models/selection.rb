class Selection < ApplicationRecord
  belongs_to :user
  belongs_to :gameweek

  validates :user_id, uniqueness: { scope: :gameweek_id }
  validates :picks, format: { with: PackHand::FORMAT }
  validate :within_the_pack
  validate :before_the_deadline, if: :picks_changed?

  def self.deal(user, gameweek)
    find_by(user: user, gameweek: gameweek) || (draw(user, gameweek) if gameweek.pack_open?)
  end

  def self.draw(user, gameweek)
    pack = PackDraw.call(gameweek: gameweek)
    create!(user: user, gameweek: gameweek, offered: pack.dump) if pack
  rescue ActiveRecord::RecordNotUnique
    find_by(user: user, gameweek: gameweek)
  end

  def pack
    @pack ||= Pack.load(offered)
  end

  def pack_hand
    code = gameweek.started? ? picks.ljust(pack.size, PackHand::FORFEIT) : picks
    PackHand.parse(pack, code)
  end

  def complete? = pack_hand&.complete?

  def pick(choice)
    return false if complete? || !PackHand::CHOICES.include?(choice)

    self.picks += choice
    save
  end

  private

  def within_the_pack
    errors.add(:picks, "is longer than the pack") if picks.size > offered.size
  end

  def before_the_deadline
    errors.add(:base, "The deadline has passed.") if gameweek&.started?
  end
end
