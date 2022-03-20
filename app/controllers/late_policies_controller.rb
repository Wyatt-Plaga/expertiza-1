class LatePoliciesController < ApplicationController
  include AuthorizationHelper

  def action_allowed?
    case params[:action]
    when 'new', 'create', 'index'
      current_user_has_ta_privileges?
    when 'edit', 'update', 'destroy'
      current_user_has_ta_privileges? &&
        current_user.instructor_id == instructor_id
    end
  end

  def index
    @penalty_policies = LatePolicy.all
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render xml: @penalty_policies }
    end
  end

  def show
    @penalty_policy = LatePolicy.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render xml: @penalty_policy }
    end
  end

  def new
    @penalty_policy = LatePolicy.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render xml: @penalty_policy }
    end
  end

  def edit
    @penalty_policy = LatePolicy.find(params[:id])
  end

  def create
    valid_penalty, error_message = validate_input
    if error_message
        flash[:error] = error_message
    end

    if valid_penalty
      @late_policy = LatePolicy.new(late_policy_params)
      @late_policy.instructor_id = instructor_id
      begin
        @penalty_policy.save!
        flash[:notice] = 'The late policy was successfully created.'
        redirect_to action: 'index'
      rescue StandardError
        flash[:error] = 'The following error occurred while saving the late policy: '
        redirect_to action: 'new'
      end
    else
      redirect_to action: 'new'
    end
  end

  def update
      # NOTE: While we consolidated the input validation for create and update,
      # there were some difference in error messages that was lost.
      # error message from this function would contain "cannot edit the policy"
      # and duplicate name error would return the duplicate name in the error
      # message. TODO: need to check this is not breaking any tests.
    penalty_policy = LatePolicy.find(params[:id])

    valid_penalty, error_message = validate_input
    if error_message
      flash[:error] = error_message
      redirect_to action: 'edit', id: params[:id]
    else
      begin
        penalty_policy.update_attributes(late_policy_params)
        penalty_policy.save!
        LatePolicy.update_calculated_penalty_objects(penalty_policy)
        flash[:notice] = 'The late policy was successfully updated.'
        redirect_to action: 'index'
      rescue StandardError
        flash[:error] = 'The following error occurred while updating the late policy: '
        redirect_to action: 'edit', id: params[:id]
      end
    end
  end

  def destroy
    @penalty_policy = LatePolicy.find(params[:id])
    begin
      @penalty_policy.destroy
    rescue StandardError
      flash[:error] = 'This policy is in use and hence cannot be deleted.'
    end
    redirect_to controller: 'late_policies', action: 'index'
  end

  private

  def late_policy_params
    params.require(:late_policy).permit(:policy_name, :penalty_per_unit, :penalty_unit, :max_penalty)
  end

  def instructor_id
    late_policy.try(:instructor_id) ||
      current_user.instructor_id
  end

  def late_policy
    @penalty_policy ||= @late_policy || LatePolicy.find(params[:id]) if params[:id]
  end

  def validate_input 
    # Validates input for create and update forms

    valid_penalty = true
    error_message = nil

    max_penalty = params[:late_policy][:max_penalty].to_i

    invalid_penalty_per_unit = max_penalty < params[:late_policy][:penalty_per_unit].to_i
    if invalid_penalty_per_unit
      error_message = 'The maximum penalty cannot be less than penalty per unit.'
      valid_penalty = false
    end

    if LatePolicy.check_policy_with_same_name(params[:late_policy][:policy_name], instructor_id)
      error_message = 'A policy with the same name already exists.'
      valid_penalty = false
    end

    if max_penalty >= 100
      error_message = 'Maximum penalty cannot be greater than or equal to 100'
      valid_penalty = false
    end

    return valid_penalty, error_message
  end

end
