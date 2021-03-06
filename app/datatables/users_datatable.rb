class UsersDatatable
  include Rails.application.routes.url_helpers
  delegate :params, :h, :link_to, :number_to_currency, :image_tag, :number_with_delimiter, to: :@view
  delegate :current_user, to: :@current_user

  def initialize(view, current_user)
    @view = view
    @current_user = current_user
  end

  def as_json(options = {})
    {
      draw: params[:draw].to_i,
      recordsTotal: user_query.count,
      recordsFiltered: users.total_count,
      data: data
    }
  end

private

  def data
    users.map do |user|
      [
        user.name,
        user.user_or_org,
        user.dataset_count,
        user.role_name.humanize,
        I18n.l(user.created_at, :format => :file),
        user.current_sign_in_at.present? ? I18n.l(user.current_sign_in_at, :format => :file) : nil,
        user.sign_in_count,
        action_links(user)
      ]
    end
  end

  def users
    @users ||= fetch_users
  end

  def action_links(user)
    x = ''
    x << link_to('',
                      edit_admin_user_path(user, :locale => I18n.locale), 
                      :title => I18n.t("helpers.links.edit"),
                      :class => 'btn btn-edit btn-xs')
    x << " "
    x << link_to('',
                      admin_user_path(user, :locale => I18n.locale),
                      :title => I18n.t("helpers.links.destroy"),
                      :method => :delete,
											:data => { :confirm => I18n.t("helpers.links.confirm") },
                      :class => 'btn btn-delete btn-xs')
    return x.html_safe
  end

  def user_query
    if @current_user.present? && @current_user.role == User::ROLES[:admin]
      User
    else
      User.no_admins
    end
  end

  def fetch_users
    users = user_query.order_by([[sort_column, sort_direction]])
    users = users.page(page).per(per_page)
    if params[:search].present? && params[:search][:value].present?
      users = users.or({email: /#{params[:search][:value]}/i}, {last_name: /#{params[:search][:value]}/i}, {first_name: /#{params[:search][:value]}/i})
    end
    users
  end

  def page
    params[:start].to_i/per_page + 1
  end

  def per_page
    params[:length].to_i > 0 ? params[:length].to_i : 10
  end

  def sort_column
    columns = %w[last_name is_user last_name role created_at current_sign_in_at sign_in_count]
    columns[params[:order]['0'][:column].to_i]
  end

  def sort_direction
    params[:order]['0'][:dir] == "desc" ? "desc" : "asc"
  end
end
