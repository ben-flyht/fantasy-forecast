class PackMailerPreview < ActionMailer::Preview
  def pack_link
    user = User.find_or_create_by!(email: "preview@example.com") { |u| u.assign_attributes(first_name: "Preview", last_name: "Player") }
    PackMailer.with(user: user, gameweek: Gameweek.next_gameweek).pack_link
  end
end
