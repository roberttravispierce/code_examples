class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :show_section, :edit, :update, :destroy]

  def index
    @network_filter = (params[:n].present? && params[:n] != "all") ? params[:n] : "all"
    @state_filter = (params[:s].present? && params[:s] != "all") ? params[:s] : "all"
    if @network_filter == "all"
      @project_count_for_network = Project.all.count
      if @state_filter == "all"
        @projects = Project.includes(:network).ordered_by_year.sort_by_params(params[:sort], sort_direction)
      else
        @projects = Project.send(@state_filter).includes(:network).ordered_by_year.sort_by_params(params[:sort], sort_direction)
      end
    else
      @project_count_for_network = Project.for_network(@network_filter.upcase).count
      @network = Network.find_by_code(@network_filter.upcase)
      if @state_filter == "all"
        @projects = Project.for_network(@network_filter.upcase).ordered_by_year.sort_by_params(params[:sort], sort_direction)
      else
        @projects = Project.send(@state_filter).for_network(@network_filter.upcase).ordered_by_year.sort_by_params(params[:sort], sort_direction)
      end
    end
  end

  def show
    track_project_action("Viewed")
    @year = @project.year
    @project_pcode = @project.pcode

    # Ahoy::Event.where(name: "Viewed product").where_properties(product_id: 123).count
    @project_events = Ahoy::Event.where_props(pcode: @project.pcode, action: "Updated").or(Ahoy::Event.where_props(pcode: @project.pcode, action: "Created")).order(time: :desc)

    # Post.where(id: 1).or(Post.where(title: 'Learn Rails'))

    # TODO: gotta be a better way using merge to not have to brute force this
    # project_updated_events = Ahoy::Event.where_props(pcode: @project.pcode, action: "Updated").order(time: :desc)
    # project_created_events = Ahoy::Event.where_props(pcode: @project.pcode, action: "Created").order(time: :desc)
    # @project_events = Ahoy::Event.none
    # project_updated_events.each do |event|
    #   @project_events.new(event)
    # end
    # project_created_events.each do |event|
    #   @project_events.new(event)
    # end

    if params[:section].present?
      render partial: "projects/sections/#{params[:section]}", locals: { project: @project }
    end
  end

  def new
    @year = params[:year].present? ? params[:year].to_i : Time.new.year
    @project_pcode = Project.next_pcode(@year)
    @project = Project.new
    @project.network = params[:network_id].present? ? Network.find(params[:network_id]) : Network.find_by_code('3ABN')
  end

  def edit
    @year = @project.year
    @project_pcode = @project.pcode
    if params[:section].present?
      render partial: "projects/sections/#{params[:section]}", locals: { project: @project, open: true }
    end
  end

  def create
    @project = Project.new(project_params)
    respond_to do |format|
      if @project.save!
        track_project_action("Created")
        format.html { redirect_to @project, notice: 'Project was successfully created.' }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace('project_form', partial: "projects/form_for_new", locals: { project: @project, year: @year, project_pcode: @project_pcode }), status: 400
        end
      end
    end
  end

  def update
    respond_to do |format|
      if @project.update(project_params)
        track_project_action("Updated")
        # format.html { redirect_to @project, notice: "Project was successfully updated." }
        format.html do |format|
          render partial: "projects/sections/#{params[:section]}", locals: { project: @project, open: true }
        end
      else
        format.html do
          render "edit", locals: { project: @project, year: @year, project_pcode: @project_pcode }
        end
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace('project_form', partial: "projects/form", locals: { project: @project, year: @year, project_pcode: @project_pcode }), status: 400
        end
      end
    end
  end

  def destroy
    track_project_action("Destroyed")
    @project.destroy
    redirect_to projects_url, notice: "Project was successfully destroyed."
  end

  def history
    redirect_to root_path unless user_signed_in? && current_user.has_administrator_rights?
    @versions = PaperTrail::Version.order('created_at DESC')
  end

  # def delete_image_attachment
  #     @space_image = ActiveStorage::Attachment.find(params[:id])
  #   @space_image.purge
  #   redirect_back(fallback_location: request.referer)
  # end

  def delete_file
   file = ActiveStorage::Attachment.find(params[:id])
   file.purge

   # ActiveStorage::Attachment.find(params[:file_id]).purge
   track_project_action("Deleted attachment")
   format.html do |format|
     render partial: "projects/sections/#{params[:section]}", locals: { project: params[:project], open: params[:open] }
   end
   # redirect_back(fallback_location: projects_path)
  end

  private

    def set_project
      @project = Project.friendly.find(params[:id])
      @previous_project = @project.previous
      @next_project = @project.next
    end

    def allowed_params
      ap = []
      ap << [:network_id,
            :serial_id,
            :description,
            :dist_title,
            :dist_description,
            :name,
            :notes,
            :ptype,
            :state,
            :phase,
            :relationships,
            :est_trt,
            :recorded_at,
            :sched_record_date,
            :other_air_dates,
            :prov_dist_code,
            :release_date,
            :hosts,
            :guests,
            :historical_notes,
            :first_air_date,
            :distributed_at,
            :dist_trt_str,
            :dist_notes,
            :script_notes,
            :music_notes,
            :dist_channels,
            :qc_video,
            :feature_image,
            :live_editor,
            :delivery_editor,
            :qc_approver,
            :qc_approved_at,
            :delivered_by,
            :delivered_at,
            :delivered_at,
            :delivery_notes,
            :audio_lead,
            :audio_notes,
            :ch01_type,
            :ch01_note,
            :ch01_proc,
            :ch02_type,
            :ch02_note,
            :ch02_proc,
            :ch03_type,
            :ch03_note,
            :ch03_proc,
            :ch04_type,
            :ch04_note,
            :ch04_proc,
            :ch05_type,
            :ch05_note,
            :ch05_proc,
            :ch06_type,
            :ch06_note,
            :ch06_proc,
            :ch07_type,
            :ch07_note,
            :ch07_proc,
            :ch08_type,
            :ch08_note,
            :ch08_proc,
            :ch09_type,
            :ch09_note,
            :ch09_proc,
            :ch10_type,
            :ch10_note,
            :ch10_proc,
            :ch11_type,
            :ch11_note,
            :ch11_proc,
            :ch12_type,
            :ch12_note,
            :ch12_proc,
            :ch13_type,
            :ch13_note,
            :ch13_proc,
            :ch14_type,
            :ch14_note,
            :ch14_proc,
            :ch15_type,
            :ch15_note,
            :ch15_proc,
            :ch16_type,
            :ch16_note,
            :ch16_proc,
            files: []] if current_user.has_employee_rights?
      ap << [:pcode, :year, :dist_code] if current_user.has_manager_rights?
      return ap
    end

    def project_params
      params.require(:project).permit(*allowed_params)
    end

    def track_project_action(action)
      ptype = @project.ptype.titleize if @project.ptype?
      serial_code = @project.serial.serial_code if @project.serial
      network_name = @project.network.short_name if @project.network
      phase = @project.phase.titleize if @project.phase?
      ahoy.track "Project #{@project.id}",
                  project: @project.id,
                  pcode: @project.pcode,
                  name: @project.name,
                  network_name: @project.network.short_name,
                  ptype: ptype,
                  serial_code: serial_code,
                  current_dist_code: network_name,
                  phase: phase,
                  action: action
    end
end
