class ModeratorsController < ApplicationController
  before_action :login_required

  def destroy
    Moderatorship.where('id = ?', params[:id]).delete_all
    redirect_to user_path(params[:user_id])
  end
  
  alias authorized? admin?
end
