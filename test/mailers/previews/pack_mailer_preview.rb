class PackMailerPreview < ActionMailer::Preview
  def pack_link
    manager = Manager.find_or_create_by!(email: "preview@example.com") { |m| m.assign_attributes(first_name: "Preview", last_name: "Player") }
    PackMailer.with(manager: manager, gameweek: Gameweek.next_gameweek).pack_link
  end
end
