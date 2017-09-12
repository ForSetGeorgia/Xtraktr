class TimeSeriesGroupsController < ApplicationController
  before_filter :allow_time_series
  before_filter :authenticate_user!
  before_filter :load_owner # set @owner variable
  before_filter(except: [:group_questions]) {load_time_series(params[:time_series_id])} # set @time_series variable using @owner
  before_filter do |controller_instance|
    controller_instance.send(:valid_role?, @data_editor_role)
  end

  # GET /groups
  # GET /groups.json
  def index
    @items = @time_series.arranged_items(include_questions: true, include_groups: true, include_subgroups: true)

    add_common_options(false)

    respond_to do |format|
      format.html
      format.js { render json: @items}
    end
  end

  # # GET /groups/1
  # # GET /groups/1.json
  # def show
  #   @group = Group.find(params[:id])

  #   respond_to do |format|
  #     format.html # show.html.erb
  #     format.json { render json: @group }
  #   end
  # end

  # GET /groups/new
  # GET /groups/new.json
  def new
    @group = @time_series.groups.new

    add_common_options

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @group }
    end
  end

  # GET /groups/1/edit
  def edit
    @group = @time_series.groups.find(params[:id])

    add_common_options
  end

  # POST /groups
  # POST /groups.json
  def create
    @group = @time_series.groups.new(params[:time_series_group])

    # check if group is valid
    # - if not, stop
    if @group.valid?
      # assign the group ids to the questions
      if params[:time_series].present? && params[:time_series][:time_series_questions_attributes].present?
        selected_ids = params[:time_series][:time_series_questions_attributes].select{|k,v| v[:selected] == 'true'}.map{|k,v| v[:id]}
        not_selected_ids = params[:time_series][:time_series_questions_attributes].select{|k,v| v[:selected] != 'true'}.map{|k,v| v[:id]}
      end
      # have to have subgroups or questions in order to be saved
      if (selected_ids.present? && selected_ids.length > 0) ||
          (not_selected_ids.present? && not_selected_ids.length > 0) ||
          @group.subgroups.length > 0
        if (selected_ids.present? && selected_ids.length > 0)
          @time_series.questions.assign_group(selected_ids, @group.id)
        end
        if (not_selected_ids.present? && not_selected_ids.length > 0)
          @time_series.questions.assign_group(not_selected_ids, @group.parent_id.present? ? @group.parent_id : nil)
        end

        respond_to do |format|
          if @time_series.save
            format.html { redirect_to time_series_time_series_groups_path(@owner), flash: {success:  t('app.msgs.success_created', :obj => t('mongoid.models.group.one'))} }
            format.json { render json: @group, status: :created, location: @group }
          else
            logger.debug "!!!!!!!!!!! error = #{@time_series.errors.messages.inspect}"
            add_common_options

            format.html { render action: "new" }
            format.json { render json: @group.errors, status: :unprocessable_entity }
          end
        end
      else
        @group.add_missing_questions_error

        respond_to do |format|
          add_common_options

          format.html { render action: "new" }
          format.json { render json: @group.errors, status: :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
        add_common_options

        format.html { render action: "new" }
        format.json { render json: @group.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /groups/1
  # PUT /groups/1.json
  def update
    @group = @time_series.groups.find(params[:id])
    @group.assign_attributes(params[:time_series_group])

    # check if group is valid
    # - if not, stop
    if @group.valid?
      # assign the group ids to the questions
      if params[:time_series].present? && params[:time_series][:time_series_questions_attributes].present?
        selected_ids = params[:time_series][:time_series_questions_attributes].select{|k,v| v[:selected] == 'true'}.map{|k,v| v[:id]}
        not_selected_ids = params[:time_series][:time_series_questions_attributes].select{|k,v| v[:selected] != 'true'}.map{|k,v| v[:id]}
      end

      # have to have subgroups or questions in order to be saved
      if (selected_ids.present? && selected_ids.length > 0) ||
          (not_selected_ids.present? && not_selected_ids.length > 0) ||
          @group.subgroups.length > 0
        if (selected_ids.present? && selected_ids.length > 0)
          @time_series.questions.assign_group(selected_ids, @group.id)
        end
        if (not_selected_ids.present? && not_selected_ids.length > 0)
          @time_series.questions.assign_group(not_selected_ids, @group.parent_id.present? ? @group.parent_id : nil)
        end
        respond_to do |format|
          if @time_series.save
            format.html { redirect_to time_series_time_series_groups_path(@owner), flash: {success:  t('app.msgs.success_updated', :obj => t('mongoid.models.group.one'))} }
            format.json { head :no_content }
          else
            add_common_options

            format.html { render action: "edit" }
            format.json { render json: @group.errors, status: :unprocessable_entity }
          end
        end
      else
        @group.add_missing_questions_error

        respond_to do |format|
          add_common_options

          format.html { render action: "new" }
          format.json { render json: @group.errors, status: :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
        add_common_options

        format.html { render action: "edit" }
        format.json { render json: @group.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /groups/1
  # DELETE /groups/1.json
  def destroy
    @group = @time_series.groups.find(params[:id])
    @group.destroy

    respond_to do |format|
      format.html { redirect_to time_series_time_series_groups_url(@owner), flash: {success:  t('app.msgs.success_deleted', :obj => t('mongoid.models.group.one'))} }
      format.json { head :no_content }
    end
  end

  # get the questions that can be assigned to this group and that are currently assigned to this group
  def group_questions
    if params[:time_series_id].present?
      time_series = TimeSeries.by_id_for_owner(params[:time_series_id], @owner.id, current_user.id)

      if time_series.present?
        # if group id was provided, look for questions assigned to the group
        # else get questions that do not have groups assigned yet
        questions = params[:group_id].present? ? time_series.questions.assigned_to_group_meta_only(params[:group_id]) : time_series.questions.not_assigned_group_meta_only

        # get existing group
        group = time_series.groups.find(params[:id])
        assigned_questions = []
        if group.present?
          # if the group parent id equals the group id param, then get the existing questions for this group
          # else, the parent group is changing and the existing questions are no longer valid
          if (group.parent_id.nil? && params[:group_id].empty?) || (group.parent_id.to_s == params[:group_id])
            # get questions already assigned to the group
            assigned_questions = time_series.questions.assigned_to_group_meta_only(params[:id])
          end
        end

        # combine the two sets of questions with the selected questions first
        items = sort_objects_with_sort_order(assigned_questions).map{|x| x.json_for_groups(true)} + sort_objects_with_sort_order(questions).map{|x| x.json_for_groups}

        respond_to do |format|
          format.json { render json: items }
        end
        return
      end
    end

    respond_to do |format|
      format.json { head :no_content }
    end
  end

private
  def add_common_options(for_form=true)
    @css.push("groups.css")
    @js.push("time_series_groups.js")

    if for_form
      @css.push('tabbed_translation_form.css')

      @languages = Language.sorted

      # get list of current main groups
      @main_groups = @time_series.groups.main_groups(@group.id)

      gon.insert_description_text = t('app.msgs.insert_description_text')
      gon.group_questions_path = group_questions_time_series_time_series_group_path(@owner.slug, @time_series.slug, @group.id)
    end

    add_time_series_nav_options
    set_gon_datatables

  end

end
