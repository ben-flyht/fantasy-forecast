class PredictionsController < ApplicationController
  before_action :set_prediction, only: %i[ show edit update destroy ]
  before_action :ensure_ownership, only: %i[ edit update destroy ]
  before_action :restrict_admin_edits, only: %i[ edit update destroy ]
  before_action :authenticate_user!, except: %i[ index show ]

  # GET /predictions or /predictions.json
  def index
    if current_user.admin?
      @predictions = Prediction.includes(:user, :player).all
    else
      @predictions = current_user.predictions.includes(:player)
    end

    # Group predictions for display
    @grouped_predictions = @predictions.group_by(&:category)
  end

  # GET /predictions/1 or /predictions/1.json
  def show
  end

  # GET /predictions/new
  def new
    @next_gameweek = Gameweek.next_gameweek
    @players_by_position = Player.order(:name).group_by(&:position)

    # Get current user's predictions for the next gameweek
    @current_predictions = if @next_gameweek
      current_user.predictions
                  .includes(:player)
                  .where(gameweek: @next_gameweek)
                  .group_by(&:category)
    else
      { "target" => [], "avoid" => [] }
    end
  end

  # GET /predictions/1/edit
  def edit
    @next_gameweek = Gameweek.next_gameweek
  end

  # POST /predictions or /predictions.json
  def create
    @prediction = current_user.predictions.build(prediction_params)
    @next_gameweek = Gameweek.next_gameweek

    # Ensure gameweek is set to next gameweek regardless of params
    @prediction.gameweek = @next_gameweek

    respond_to do |format|
      if @prediction.save
        format.html { redirect_to @prediction, notice: "Prediction was successfully created." }
        format.json { render :show, status: :created, location: @prediction }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @prediction.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /predictions/1 or /predictions/1.json
  def update
    respond_to do |format|
      if @prediction.update(prediction_params)
        format.html { redirect_to @prediction, notice: "Prediction was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @prediction }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @prediction.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /predictions/1 or /predictions/1.json
  def destroy
    @prediction.destroy!

    respond_to do |format|
      format.html { redirect_to predictions_path, notice: "Prediction was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # PATCH /predictions/update_prediction (AJAX)
  def update_prediction
    @next_gameweek = Gameweek.next_gameweek

    unless @next_gameweek
      render json: { error: "No upcoming gameweek available" }, status: :unprocessable_entity
      return
    end

    player_id = params[:player_id]
    category = params[:category]
    position = params[:position]
    slot = params[:slot]

    # Start a transaction to handle the update
    ActiveRecord::Base.transaction do
      if player_id.present?
        # Check if this player is already selected anywhere for this gameweek
        existing_prediction = current_user.predictions
                                         .where(gameweek: @next_gameweek, player_id: player_id)
                                         .first

        if existing_prediction
          # Player already selected, remove the existing prediction
          existing_prediction.destroy!
        end

        # Create new prediction
        current_user.predictions.create!(
          player_id: player_id,
          category: category,
          gameweek: @next_gameweek
        )
      end
    end

    # Reload the data for the response
    @players_by_position = Player.order(:name).group_by(&:position)
    @current_predictions = if @next_gameweek
      current_user.predictions
                  .includes(:player)
                  .where(gameweek: @next_gameweek)
                  .group_by(&:category)
    else
      { "target" => [], "avoid" => [] }
    end

    respond_to do |format|
      format.turbo_stream { render template: "predictions/sync_all" }
      format.html { redirect_to new_prediction_path }
    end

  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "RecordInvalid error: #{e.record.errors.full_messages.join(', ')}"
    # Reload the data for error response
    @players_by_position = Player.order(:name).group_by(&:position)
    @current_predictions = if @next_gameweek
      current_user.predictions
                  .includes(:player)
                  .where(gameweek: @next_gameweek)
                  .group_by(&:category)
    else
      { "target" => [], "avoid" => [] }
    end

    respond_to do |format|
      format.turbo_stream { render template: "predictions/sync_all" }
    end
  rescue => e
    Rails.logger.error "General error: #{e.message}"
    # Reload the data for error response
    @players_by_position = Player.order(:name).group_by(&:position)
    @current_predictions = if @next_gameweek
      current_user.predictions
                  .includes(:player)
                  .where(gameweek: @next_gameweek)
                  .group_by(&:category)
    else
      { "target" => [], "avoid" => [] }
    end

    respond_to do |format|
      format.turbo_stream { render template: "predictions/sync_all" }
    end
  end

  # POST /predictions/sync_all (AJAX)
  def sync_all
    @next_gameweek = Gameweek.next_gameweek

    unless @next_gameweek
      render json: { error: "No upcoming gameweek available" }, status: :unprocessable_entity
      return
    end

    predictions_data = params[:predictions] || {}
    Rails.logger.debug "Received predictions data: #{predictions_data.inspect}"

    # Start a transaction to ensure all-or-nothing update
    ActiveRecord::Base.transaction do
      # Delete all existing predictions for this user and gameweek
      current_user.predictions.where(gameweek: @next_gameweek).destroy_all

      # Collect all player selections and deduplicate - process in reverse order
      # so that later selections override earlier ones
      selected_players = {}
      predictions_to_create = []

      # Process in reverse order: last selection wins
      predictions_data.each do |category, positions|
        positions.each do |position, slots|
          slots.to_a.reverse.each do |slot, player_id|
            next if player_id.blank?

            # Skip if we've already processed this player (later selection wins)
            if selected_players.key?(player_id)
              Rails.logger.debug "Skipping duplicate player: #{player_id} in #{category} #{position} (already selected as #{selected_players[player_id]})"
              next
            end

            selected_players[player_id] = "#{category} #{position} slot #{slot}"
            predictions_to_create << {
              player_id: player_id,
              category: category,
              gameweek: @next_gameweek
            }
          end
        end
      end

      # Create deduplicated predictions
      predictions_to_create.each do |prediction_attrs|
        Rails.logger.debug "Creating prediction: user=#{current_user.id}, player=#{prediction_attrs[:player_id]}, category=#{prediction_attrs[:category]}, gameweek=#{@next_gameweek.id}"
        current_user.predictions.create!(prediction_attrs)
      end
    end

    # Return response based on request format
    count = current_user.predictions.where(gameweek: @next_gameweek).count

    # Reload the data for the response
    @players_by_position = Player.order(:name).group_by(&:position)
    @current_predictions = if @next_gameweek
      current_user.predictions
                  .includes(:player)
                  .where(gameweek: @next_gameweek)
                  .group_by(&:category)
    else
      { "target" => [], "avoid" => [] }
    end

    respond_to do |format|
      format.json { render json: { success: true, count: count, message: "Synced #{count} predictions" } }
      format.turbo_stream # Uses sync_all.turbo_stream.erb template
    end

  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "RecordInvalid error: #{e.record.errors.full_messages.join(', ')}"
    # Reload the data for error response
    @players_by_position = Player.order(:name).group_by(&:position)
    @current_predictions = if @next_gameweek
      current_user.predictions
                  .includes(:player)
                  .where(gameweek: @next_gameweek)
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
    @players_by_position = Player.order(:name).group_by(&:position)
    @current_predictions = if @next_gameweek
      current_user.predictions
                  .includes(:player)
                  .where(gameweek: @next_gameweek)
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
    def set_prediction
      @prediction = Prediction.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def prediction_params
      # Only allow player_id and category since gameweek is auto-assigned
      allowed_params = [ :player_id, :category ]
      params.expect(prediction: allowed_params)
    end

    # Ensure only the prediction owner can edit/delete
    def ensure_ownership
      unless current_user.admin? || @prediction.user == current_user
        redirect_to predictions_path, alert: "You can only edit your own predictions."
      end
    end

    # Prevent admins from editing prophet predictions
    def restrict_admin_edits
      if current_user.admin? && @prediction.user.prophet?
        redirect_to predictions_path, alert: "Admins cannot edit Prophet predictions."
      end
    end
end
