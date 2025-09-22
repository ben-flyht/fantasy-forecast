json.extract! forecast, :id, :user_id, :player_id, :gameweek_id, :category, :created_at, :updated_at
json.url forecast_url(forecast, format: :json)
