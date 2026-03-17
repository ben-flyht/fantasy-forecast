import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit(event) {
    event.preventDefault()

    const form = this.element
    const data = new FormData(form)
    const gameweek = data.get("gameweek")
    const position = data.get("position") || "forward"
    const teamId = data.get("team_id")
    const draftTeam = data.get("draft_team")

    const plurals = { goalkeeper: "goalkeepers", defender: "defenders", midfielder: "midfielders", forward: "forwards" }
    let path = `/gameweeks/${gameweek}/${plurals[position] || `${position}s`}`

    const params = new URLSearchParams()
    if (teamId) params.set("team_id", teamId)
    if (draftTeam) params.set("draft_team", draftTeam)
    if (params.toString()) path += `?${params}`

    Turbo.visit(path, { frame: "rankings_container", action: "advance" })
  }
}
