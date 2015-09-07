class SettingsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_owner # set @owner variable

  def index
    @user = @owner

    if request.put? &&
      success = if params[:user][:password].present? || params[:user][:password_confirmation].present?
        @user.update_attributes(params[:user])
      else
        @user.update_without_password(params[:user])
      end

      if success
        flash[:success] = t('app.msgs.user_settings_updated')
      end
    end

    @css.push('tabs.css', 'settings.css')

    respond_to do |format|
      format.html # index.html.erb
    end
  end


  def get_api_token
    @user = @owner

    @user.api_keys.create

    flash[:success] = t('app.msgs.api_key_created')

    redirect_to settings_path(owner_id: @owner.slug, page: 'api')
  end

  def delete_api_token
    @user = @owner

    key = @user.api_keys.where(id: params[:id]).first

    if key.present?
      key.destroy
    end

    flash[:success] = t('app.msgs.api_key_deleted')

    redirect_to settings_path(owner_id: @owner.slug, page: 'api')
  end


  def edit_organization
    @user = @owner
    @group = User.find(params[:id])
    if @group.present? && @owner.groups.in_group?(@group.id)
      if request.put?
        if @group.update_attributes(params[:user])
          respond_to do |format|
            format.html { redirect_to settings_path(@owner, page: 'organizations'), flash: {success:  t('app.msgs.success_saved', :obj => t('mongoid.models.group'))} }
          end
        else
          respond_to do |format|
            format.html # index.html.erb
          end
        end
      else
        respond_to do |format|
          format.html # index.html.erb
        end
      end
    else
      flash[:info] =  t('app.msgs.does_not_exist')
      redirect_to settings_path(:owner_id => @owner.slug, page: 'organizations')
      return
    end

  end
end
