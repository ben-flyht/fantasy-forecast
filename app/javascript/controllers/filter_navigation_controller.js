import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit(event) {
    event.preventDefault()

    const form = this.element
    const data = new FormData(form)
    const gameweek = data.get("gameweek")
    const position = data.get("position") || "forward"
    const teamId = data.get("team_id")

    const plurals = { goalkeeper: "goalkeepers", defender: "defenders", midfielder: "midfielders", forward: "forwards" }
    const plural = plurals[position] || `${position}s`

    // The season has a page of its own; a week is named by its number. This
    // mirrors PlayersController#rankings_path, and has to: sending the season to
    // /gameweeks/season is a route that has never existed, and Turbo answers a
    // 404 inside a frame with the words "Content missing".
    let path = gameweek === "season" ? `/season/${plural}` : `/gameweeks/${gameweek}/${plural}`

    const params = new URLSearchParams()
    if (teamId) params.set("team_id", teamId)
    if (params.toString()) path += `?${params}`

    Turbo.visit(path, { frame: "rankings_container", action: "advance" })
  }
}
