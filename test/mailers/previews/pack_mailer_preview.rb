class PackMailerPreview < ActionMailer::Preview
  def pack_link
    manager = Manager.find_or_create_by!(email: "preview@example.com")
    PackMailer.with(manager: manager, gameweek: Gameweek.next_gameweek).pack_link
  end
end
