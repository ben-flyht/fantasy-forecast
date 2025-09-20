# FPL API Player Attributes Reference

This document outlines all available player attributes from the FPL (Fantasy Premier League) API `bootstrap-static/elements` endpoint.

## API Endpoint
- **URL**: `https://fantasy.premierleague.com/api/bootstrap-static/`
- **Section**: `elements` array contains player data

## Currently Used Attributes

The following attributes are currently implemented in `app/services/fpl/sync_players.rb`:

| Attribute | Type | Description | Usage |
|-----------|------|-------------|-------|
| `id` | Integer | Unique FPL player identifier | Stored as `fpl_id` |
| `first_name` | String | Player's first name | Combined with `second_name` for full name |
| `second_name` | String | Player's last name | Combined with `first_name` for full name |
| `web_name` | String | Short display name (e.g., "Haaland") | Stored as `short_name` |
| `team` | Integer | Team ID (maps to team names) | Mapped to team name via teams hash |
| `element_type` | Integer | Position type | Mapped: 1=GK, 2=DEF, 3=MID, 4=FWD |
| `selected_by_percent` | Float | Ownership percentage | Stored as `ownership_percentage` |

## Additional Available Attributes

### Performance Statistics
| Attribute | Type | Description |
|-----------|------|-------------|
| `total_points` | Integer | Total fantasy points this season |
| `goals_scored` | Integer | Goals scored this season |
| `assists` | Integer | Assists this season |
| `clean_sheets` | Integer | Clean sheets (defenders/goalkeepers) |
| `goals_conceded` | Integer | Goals conceded (defenders/goalkeepers) |
| `own_goals` | Integer | Own goals scored |
| `penalties_saved` | Integer | Penalties saved (goalkeepers) |
| `penalties_missed` | Integer | Penalties missed |
| `yellow_cards` | Integer | Yellow cards received |
| `red_cards` | Integer | Red cards received |
| `saves` | Integer | Saves made (goalkeepers) |
| `bonus` | Integer | Bonus points earned |
| `bps` | Integer | Bonus points system score |
| `minutes` | Integer | Minutes played this season |

### Pricing & Financial Data
| Attribute | Type | Description |
|-----------|------|-------------|
| `now_cost` | Integer | Current player price (in tenths, e.g., 125 = £12.5m) |
| `cost_change_start` | Integer | Price change since season start |
| `cost_change_event` | Integer | Price change since last gameweek |
| `cost_change_start_fall` | Integer | Price decreases since season start |
| `dreamteam_count` | Integer | Times selected in dream team |

### Performance Metrics
| Attribute | Type | Description |
|-----------|------|-------------|
| `form` | String | Recent form rating |
| `points_per_game` | String | Average points per game |
| `value_form` | String | Value rating based on recent form |
| `value_season` | String | Value rating based on season performance |
| `influence` | String | Influence rating (key passes, shots, etc.) |
| `creativity` | String | Creativity rating (chances created) |
| `threat` | String | Threat rating (shots, touches in box) |
| `ict_index` | String | Combined ICT (Influence, Creativity, Threat) index |

### Player Status & Availability
| Attribute | Type | Description |
|-----------|------|-------------|
| `status` | String | Player status (a=available, i=injured, s=suspended, etc.) |
| `news` | String | Latest news about the player |
| `chance_of_playing_this_round` | Integer | Likelihood of playing this gameweek (0-100) |
| `chance_of_playing_next_round` | Integer | Likelihood of playing next gameweek (0-100) |

### Additional Metadata
| Attribute | Type | Description |
|-----------|------|-------------|
| `code` | Integer | Player code identifier |
| `ep_this` | String | Expected points this gameweek |
| `ep_next` | String | Expected points next gameweek |
| `event_points` | Integer | Points scored in latest gameweek |
| `photo` | String | Player photo filename |
| `special` | Boolean | Special status flag |
| `squad_number` | Integer | Player's squad number |
| `transfers_in` | Integer | Transfers in this gameweek |
| `transfers_out` | Integer | Transfers out this gameweek |
| `transfers_in_event` | Integer | Transfers in during latest gameweek |
| `transfers_out_event` | Integer | Transfers out during latest gameweek |

## Implementation Notes

1. **Position Mapping**: The `element_type` field maps to positions as:
   - 1 = Goalkeeper (GK)
   - 2 = Defender (DEF)
   - 3 = Midfielder (MID)
   - 4 = Forward (FWD)

2. **Pricing**: The `now_cost` is in tenths (e.g., 125 = £12.5 million)

3. **Status Codes**: Common player status values:
   - 'a' = Available
   - 'i' = Injured
   - 's' = Suspended
   - 'u' = Unavailable

4. **API Updates**: The FPL occasionally updates the API structure during off-seasons, so this reference should be validated at the start of each season.

## Usage in Application

To extend the current implementation to use more attributes:

1. Add new columns to the `players` table via migration
2. Update the `sync_players` method in `app/services/fpl/sync_players.rb`
3. Update the `Player` model with any new validations or methods
4. Consider which attributes would enhance prediction accuracy

## Related Endpoints

- `/api/element-summary/{player_id}/` - Detailed individual player data
- `/api/fixtures/` - Fixture information
- `/api/teams/` - Team information