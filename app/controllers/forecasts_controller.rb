class ForecastsController < ApplicationController
  before_action :set_forecast, only: %i[ show edit update destroy ]
  before_action :ensure_ownership, only: %i[ edit update destroy ]
  before_action :restrict_admin_edits, only: %i[ edit update destroy ]
  before_action :authenticate_user!, except: %i[ show ]

  # GET /forecasts or /forecasts.json
  def index
    if current_user&.admin?
      @forecasts = Forecast.includes(:user, :player).all
    elsif current_user
      @forecasts = current_user.forecasts.includes(:player)
    else
      @forecasts = Forecast.none
    end

    # Group forecasts for display
    @grouped_forecasts = @forecasts.group_by(&:category)
  end

  # GET /forecasts/1 or /forecasts/1.json
  def show
  end

  # GET /forecasts/new
  def new
    @current_gameweek = Gameweek.current_gameweek
    @players_by_position = Player.order(first_name: :asc, last_name: :asc).group_by(&:position)

    # Get current user's forecasts for the next gameweek
    @current_forecasts = if @next_gameweek
      current_user.forecasts
                  .includes(:player)
                  .where(gameweek: @next_gameweek)
                  .order(:id)
                  .group_by(&:category)
    else
      { "target" => [], "avoid" => [] }
    end
  end

  # GET /forecasts/1/edit
  def edit
    @current_gameweek = Gameweek.current_gameweek
  end

  # POST /forecasts or /forecasts.json
  def create
    @forecast = current_user.forecasts.build(forecast_params)
    @current_gameweek = Gameweek.current_gameweek

    # Ensure gameweek is set to next gameweek regardless of params
    @forecast.gameweek = @next_gameweek

    respond_to do |format|
      if @forecast.save
        format.html { redirect_to @forecast, notice: "Forecast was successfully created." }
        format.json { render :show, status: :created, location: @forecast }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @forecast.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /forecasts/1 or /forecasts/1.json
  def update
    respond_to do |format|
      if @forecast.update(forecast_params)
        format.html { redirect_to @forecast, notice: "Forecast was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @forecast }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @forecast.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /forecasts/1 or /forecasts/1.json
  def destroy
    @forecast.destroy!

    respond_to do |format|
      format.html { redirect_to forecasts_path, notice: "Forecast was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # PATCH /forecasts/update_forecast (AJAX)
  def update_forecast
    @current_gameweek = Gameweek.current_gameweek

    unless @next_gameweek
      render json: { error: "No upcoming gameweek available" }, status: :unprocessable_entity
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
                                       .where(gameweek: @next_gameweek, category: category, players: { position: position })
                                       .order(:id)

      # If there's a forecast at this slot index, remove it
      if position_forecasts[slot]
        position_forecasts[slot].destroy!
      end

      # If a new player is selected, create the forecast
      if player_id.present?
        # Check if this player is already selected anywhere else for this gameweek
        existing_elsewhere = current_user.forecasts
                                          .where(gameweek: @next_gameweek, player_id: player_id)
                                          .first

        if existing_elsewhere
          # Player already selected elsewhere, remove the existing forecast
          existing_elsewhere.destroy!
        end

        # Create new forecast
        current_user.forecasts.create!(
          player_id: player_id,
          category: category,
          gameweek: @next_gameweek
        )
      end
    end

    # Reload the data for the response
    @players_by_position = Player.order(first_name: :asc, last_name: :asc).group_by(&:position)
    @current_forecasts = if @next_gameweek
      current_user.forecasts
                  .includes(:player)
                  .where(gameweek: @next_gameweek)
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
    @players_by_position = Player.order(first_name: :asc, last_name: :asc).group_by(&:position)
    @current_forecasts = if @next_gameweek
      current_user.forecasts
                  .includes(:player)
                  .where(gameweek: @next_gameweek)
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
    @players_by_position = Player.order(first_name: :asc, last_name: :asc).group_by(&:position)
    @current_forecasts = if @next_gameweek
      current_user.forecasts
                  .includes(:player)
                  .where(gameweek: @next_gameweek)
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
    @current_gameweek = Gameweek.current_gameweek

    unless @next_gameweek
      render json: { error: "No upcoming gameweek available" }, status: :unprocessable_entity
      return
    end

    forecasts_data = params.permit![:forecasts] || {}
    Rails.logger.debug "Received forecasts data: #{forecasts_data.inspect}"

    # Start a transaction to ensure all-or-nothing update
    ActiveRecord::Base.transaction do
      # Delete all existing forecasts for this user and gameweek
      current_user.forecasts.where(gameweek: @next_gameweek).destroy_all

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
              gameweek: @next_gameweek
            }
          end
        end
      end

      # Create deduplicated forecasts
      forecasts_to_create.each do |forecast_attrs|
        Rails.logger.debug "Creating forecast: user=#{current_user.id}, player=#{forecast_attrs[:player_id]}, category=#{forecast_attrs[:category]}, gameweek=#{@next_gameweek.id}"
        current_user.forecasts.create!(forecast_attrs)
      end
    end

    # Return response based on request format
    count = current_user.forecasts.where(gameweek: @next_gameweek).count

    # Reload the data for the response
    @players_by_position = Player.order(first_name: :asc, last_name: :asc).group_by(&:position)
    @current_forecasts = if @next_gameweek
      current_user.forecasts
                  .includes(:player)
                  .where(gameweek: @next_gameweek)
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
    @players_by_position = Player.order(first_name: :asc, last_name: :asc).group_by(&:position)
    @current_forecasts = if @next_gameweek
      current_user.forecasts
                  .includes(:player)
                  .where(gameweek: @next_gameweek)
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
    @players_by_position = Player.order(first_name: :asc, last_name: :asc).group_by(&:position)
    @current_forecasts = if @next_gameweek
      current_user.forecasts
                  .includes(:player)
                  .where(gameweek: @next_gameweek)
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
    # Use callbacks to share common setup or constraints between actions.
    def set_forecast
      @forecast = Forecast.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def forecast_params
      # Only allow player_id and category since gameweek is auto-assigned
      allowed_params = [ :player_id, :category ]
      params.expect(forecast: allowed_params)
    end

    # Ensure only the forecast owner can edit/delete
    def ensure_ownership
      unless current_user.admin? || @forecast.user == current_user
        redirect_to forecasts_path, alert: "You can only edit your own forecasts."
      end
    end

    # Prevent admins from editing forecaster forecasts
    def restrict_admin_edits
      if current_user.admin? && @forecast.user.forecaster?
        redirect_to forecasts_path, alert: "Admins cannot edit forecaster forecasts."
      end
    end
end
