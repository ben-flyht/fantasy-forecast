class PredictionsController < ApplicationController
  before_action :set_prediction, only: %i[ show edit update destroy ]
  before_action :ensure_ownership, only: %i[ edit update destroy ]
  before_action :restrict_admin_edits, only: %i[ edit update destroy ]

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
    @prediction = current_user.predictions.build
    @next_gameweek = Gameweek.next_gameweek
  end

  # GET /predictions/1/edit
  def edit
    @next_gameweek = Gameweek.next_gameweek
  end

  # POST /predictions or /predictions.json
  def create
    @prediction = current_user.predictions.build(prediction_params)
    @next_gameweek = Gameweek.next_gameweek

    # For weekly predictions, ensure gameweek is set to next gameweek regardless of params
    if @prediction.weekly?
      @prediction.gameweek = @next_gameweek
    end

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

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_prediction
      @prediction = Prediction.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def prediction_params
      # Exclude week and gameweek_id for weekly predictions since they're auto-assigned
      allowed_params = [ :player_id, :season_type, :category ]

      # Only allow week for rest_of_season predictions (though it's not used)
      prediction_data = params.expect(prediction: allowed_params)

      # Prevent tampering with gameweek_id by never allowing it in params
      prediction_data.except(:gameweek_id, :week)
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
