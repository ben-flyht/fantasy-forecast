json.extract! prediction, :id, :user_id, :player_id, :week, :season_type, :category, :created_at, :updated_at
json.url prediction_url(prediction, format: :json)
