class ForecastsController < ApplicationController
  before_action :authenticate_user!

  # GET /forecasts/new
  def new
    @current_gameweek = Gameweek.next_gameweek
    # Load players with their total scores pre-calculated and ordered by score
    players_with_scores = Player.joins("LEFT JOIN performances ON performances.player_id = players.id")
                                .select("players.*, COALESCE(SUM(performances.gameweek_score), 0) AS total_score_cached")
                                .group("players.id")
                                .order("total_score_cached DESC, first_name, last_name")
    @players_by_position = players_with_scores.group_by(&:position)

    # Get current user's forecasts for the current gameweek
    @current_forecasts = if @current_gameweek
      current_user.forecasts
                  .includes(:player)
                  .where(gameweek: @current_gameweek)
                  .order(:id)
                  .group_by(&:category)
    else
      { "target" => [], "avoid" => [] }
    end
  end


  # POST /forecasts or /forecasts.json
  def create
    @forecast = current_user.forecasts.build(forecast_params)
    @current_gameweek = Gameweek.next_gameweek

    # Ensure gameweek is set to next gameweek regardless of params
    @forecast.gameweek = @current_gameweek

    respond_to do |format|
      if @forecast.save
        format.html { redirect_to new_forecast_url, notice: "Forecast was successfully created." }
        format.json { render json: { success: true, message: "Forecast was successfully created." }, status: :created }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @forecast.errors, status: :unprocessable_entity }
      end
    end
  end


  # PATCH /forecasts/update_forecast (AJAX)
  def update_forecast
    @current_gameweek = Gameweek.next_gameweek

    unless @current_gameweek
      render json: { error: "No current gameweek available" }, status: :unprocessable_entity
      return
    end

    player_id = params[:player_id]
    category = params[:category]
    position = params[:position]
    slot = params[:slot].to_i

    # Start a transaction to handle the update
    ActiveRecord::Base.transaction do
      # Get all forecasts for this position and category, ordered consistently
      position_forecasts = current_user.forecasts
                                       .joins(:player)
                                       .where(gameweek: @current_gameweek, category: category, players: { position: position })
                                       .order(:id)

      # If there's a forecast at this slot index, remove it
      if position_forecasts[slot]
        position_forecasts[slot].destroy!
      end

      # If a new player is selected, create the forecast
      if player_id.present?
        # Check if this player is already selected anywhere else for this gameweek
        existing_elsewhere = current_user.forecasts
                                          .where(gameweek: @current_gameweek, player_id: player_id)
                                          .first

        if existing_elsewhere
          # Player already selected elsewhere, remove the existing forecast
          existing_elsewhere.destroy!
        end

        # Create new forecast
        current_user.forecasts.create!(
          player_id: player_id,
          category: category,
          gameweek: @current_gameweek
        )
      end
    end

    # Load players with their total scores pre-calculated to avoid N+1 queries
    players_with_scores = Player.joins("LEFT JOIN performances ON performances.player_id = players.id")
                                .select("players.*, COALESCE(SUM(performances.gameweek_score), 0) AS total_score_cached")
                                .group("players.id")
                                .order("total_score_cached DESC, first_name, last_name")

    @players_by_position = players_with_scores.group_by(&:position)
    @current_forecasts = if @current_gameweek
      current_user.forecasts
                  .includes(:player)
                  .where(gameweek: @current_gameweek)
                  .order(:id)
                  .group_by(&:category)
    else
      { "target" => [], "avoid" => [] }
    end

    respond_to do |format|
      format.turbo_stream { render template: "forecasts/sync_all" }
      format.html { redirect_to new_forecast_path }
    end

  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "RecordInvalid error: #{e.record.errors.full_messages.join(', ')}"
    # Reload the data for error response
    # Load players with their total scores pre-calculated and ordered by score
    players_with_scores = Player.joins("LEFT JOIN performances ON performances.player_id = players.id")
                                .select("players.*, COALESCE(SUM(performances.gameweek_score), 0) AS total_score_cached")
                                .group("players.id")
                                .order("total_score_cached DESC, first_name, last_name")
    @players_by_position = players_with_scores.group_by(&:position)
    @current_forecasts = if @current_gameweek
      current_user.forecasts
                  .includes(:player)
                  .where(gameweek: @current_gameweek)
                  .order(:id)
                  .group_by(&:category)
    else
      { "target" => [], "avoid" => [] }
    end

    respond_to do |format|
      format.turbo_stream { render template: "forecasts/sync_all" }
    end
  rescue => e
    Rails.logger.error "General error: #{e.message}"
    # Reload the data for error response
    # Load players with their total scores pre-calculated and ordered by score
    players_with_scores = Player.joins("LEFT JOIN performances ON performances.player_id = players.id")
                                .select("players.*, COALESCE(SUM(performances.gameweek_score), 0) AS total_score_cached")
                                .group("players.id")
                                .order("total_score_cached DESC, first_name, last_name")
    @players_by_position = players_with_scores.group_by(&:position)
    @current_forecasts = if @current_gameweek
      current_user.forecasts
                  .includes(:player)
                  .where(gameweek: @current_gameweek)
                  .order(:id)
                  .group_by(&:category)
    else
      { "target" => [], "avoid" => [] }
    end

    respond_to do |format|
      format.turbo_stream { render template: "forecasts/sync_all" }
    end
  end

  # POST /forecasts/sync_all (AJAX)
  def sync_all
    @current_gameweek = Gameweek.next_gameweek

    unless @current_gameweek
      render json: { error: "No current gameweek available" }, status: :unprocessable_entity
      return
    end

    forecasts_data = sync_forecasts_params || {}
    Rails.logger.debug "Received forecasts data: #{forecasts_data.inspect}"

    # Start a transaction to ensure all-or-nothing update
    ActiveRecord::Base.transaction do
      # Delete all existing forecasts for this user and gameweek
      current_user.forecasts.where(gameweek: @current_gameweek).destroy_all

      # Collect all player selections and deduplicate - process in reverse order
      # so that later selections override earlier ones
      selected_players = {}
      forecasts_to_create = []

      # Process in reverse order: last selection wins
      forecasts_data.each do |category, positions|
        positions.each do |position, slots|
          slots.to_h.to_a.reverse.each do |slot, player_id|
            next if player_id.blank?

            # Skip if we've already processed this player (later selection wins)
            if selected_players.key?(player_id)
              Rails.logger.debug "Skipping duplicate player: #{player_id} in #{category} #{position} (already selected as #{selected_players[player_id]})"
              next
            end

            selected_players[player_id] = "#{category} #{position} slot #{slot}"
            forecasts_to_create << {
              player_id: player_id,
              category: category,
              gameweek: @current_gameweek
            }
          end
        end
      end

      # Create deduplicated forecasts
      forecasts_to_create.each do |forecast_attrs|
        Rails.logger.debug "Creating forecast: user=#{current_user.id}, player=#{forecast_attrs[:player_id]}, category=#{forecast_attrs[:category]}, gameweek=#{@current_gameweek.id}"
        current_user.forecasts.create!(forecast_attrs)
      end
    end

    # Return response based on request format
    count = current_user.forecasts.where(gameweek: @current_gameweek).count

    # Reload the data for the response - optimized to only load needed fields
    # Load players with their total scores pre-calculated and ordered by score
    players_with_scores = Player.joins("LEFT JOIN performances ON performances.player_id = players.id")
                                .select("players.*, COALESCE(SUM(performances.gameweek_score), 0) AS total_score_cached")
                                .group("players.id")
                                .order("total_score_cached DESC, first_name, last_name")
    @players_by_position = players_with_scores.group_by(&:position)
    @current_forecasts = if @current_gameweek
      current_user.forecasts
                  .includes(:player)
                  .where(gameweek: @current_gameweek)
                  .order(:id)
                  .group_by(&:category)
    else
      { "target" => [], "avoid" => [] }
    end

    respond_to do |format|
      format.json { render json: { success: true, count: count, message: "Synced #{count} forecasts" } }
      format.turbo_stream # Uses sync_all.turbo_stream.erb template
    end

  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "RecordInvalid error: #{e.record.errors.full_messages.join(', ')}"
    # Reload the data for error response
    # Load players with their total scores pre-calculated and ordered by score
    players_with_scores = Player.joins("LEFT JOIN performances ON performances.player_id = players.id")
                                .select("players.*, COALESCE(SUM(performances.gameweek_score), 0) AS total_score_cached")
                                .group("players.id")
                                .order("total_score_cached DESC, first_name, last_name")
    @players_by_position = players_with_scores.group_by(&:position)
    @current_forecasts = if @current_gameweek
      current_user.forecasts
                  .includes(:player)
                  .where(gameweek: @current_gameweek)
                  .order(:id)
                  .group_by(&:category)
    else
      { "target" => [], "avoid" => [] }
    end

    respond_to do |format|
      format.json { render json: { error: e.record.errors.full_messages.join(", ") }, status: :unprocessable_entity }
      format.turbo_stream # Uses sync_all.turbo_stream.erb template
    end
  rescue => e
    Rails.logger.error "General error: #{e.message}"
    # Reload the data for error response
    # Load players with their total scores pre-calculated and ordered by score
    players_with_scores = Player.joins("LEFT JOIN performances ON performances.player_id = players.id")
                                .select("players.*, COALESCE(SUM(performances.gameweek_score), 0) AS total_score_cached")
                                .group("players.id")
                                .order("total_score_cached DESC, first_name, last_name")
    @players_by_position = players_with_scores.group_by(&:position)
    @current_forecasts = if @current_gameweek
      current_user.forecasts
                  .includes(:player)
                  .where(gameweek: @current_gameweek)
                  .order(:id)
                  .group_by(&:category)
    else
      { "target" => [], "avoid" => [] }
    end

    respond_to do |format|
      format.json { render json: { error: "An error occurred: #{e.message}" }, status: :unprocessable_entity }
      format.turbo_stream # Uses sync_all.turbo_stream.erb template
    end
  end

  private
    # Only allow a list of trusted parameters through.
    def forecast_params
      # Only allow player_id and category since gameweek is auto-assigned
      allowed_params = [ :player_id, :category ]
      params.expect(forecast: allowed_params)
    end

    # Strong parameters for sync_all action
    def sync_forecasts_params
      return {} unless params[:forecasts]

      # Define valid categories and positions from the enums
      valid_categories = %w[target avoid]
      valid_positions = %w[goalkeeper defender midfielder forward]

      # Build the permitted structure dynamically
      permitted_structure = {}
      valid_categories.each do |category|
        permitted_structure[category] = {}
        valid_positions.each do |position|
          # Allow any slot numbers (integers as strings) with player_id values
          permitted_structure[category][position] = {}
        end
      end

      # Permit only the valid structure
      params.require(:forecasts).permit(
        target: {
          goalkeeper: {},
          defender: {},
          midfielder: {},
          forward: {}
        },
        avoid: {
          goalkeeper: {},
          defender: {},
          midfielder: {},
          forward: {}
        }
      ).to_h
    end
end
