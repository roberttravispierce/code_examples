# See "doc/LICENSE" for the license governing this code.

# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def report_info_block(data, options={}, &block)
    entry_name = (options[:entry_name] ? options[:entry_name] : data.first.class.to_s) rescue 'Records'
    entry_name = 'Records' if entry_name == 'NilClasses'
    content_tag :div, :class => 'report_info_block' do
      returning String.new do |content|
        content << content_tag(:div, :class => 'report_numbers') do
          if options[:count]
            "Displaying all #{options[:count].length} #{entry_name}"
          elsif data.respond_to?(:total_pages)
            page_entries_info data, :entry_name => entry_name
          elsif data.is_a?(Array)
            "Displaying all #{data.length} #{entry_name}"
          end
        end
        content << yield if block

        if data.respond_to?(:total_pages)
          content << content_tag(:div, :class => 'pagination') do
            will_paginate data, :params => params, :container => false, :previous_label => "Prev. Page", :next_label => "Next Page"
          end
        end
        content << content_tag(:div, :class => 'data_status') do
          if data.is_a?(Array)
            data_status_indicator(data.first.class)
          else
            data_status_indicator(data)
          end
        end
      end
    end
  end

  def data_status_indicator(klass)
    content_tag :small, "Data Updated: #{klass.first(:select => 'created_at', :order => 'created_at DESC').created_at.to_s(:long) rescue '-'}",  :class => 'data_status'
  end

  def year_selector(years)
    @year_selector = true
    content_for :date_selector do
      (years + [Time.now.year, @year_num]).uniq.sort.inject('') do |content, year|
        content += link_to_function(year, "Statusroom.year_select(#{year});", :style => 'display:block;padding:3px 0;font-size:12px;')
      end
    end
  end

  def ajax_year_selector(years)
    # TODO We only want 1 year selector
    (years.map(&:to_i) + [Time.now.year, @year_num.to_i]).uniq.sort.inject('') do |content, year|
      content += link_to_function(year, "Statusroom.year_select(#{year});", :style => 'display:block;padding:3px 0;font-size:12px;')
    end
  end

  def report_filter(label, target, callback, years)
    render :partial => 'shared/report_filter', :locals => {:report_options => {:target => target, :callback => callback, :label => label, :years => years, :full => false } }
  end

  def team_selector
    optionz = ActiveSupport::OrderedHash.new
    optionz['All - (No Unit Selected)'] = ''
    @teamz.each{|team| optionz[team.name] = team.id }
    select_tag('team_selector', options_for_select(optionz, @team_id), :autocomplete => 'off')
  end

  def navigation
    @navigation
  end

  def path_params
    params.skip('sortname').skip(:sortname)
  end

  def sort_by
    @sort_by ||= params[:sortname]
  end

  def sort_direction
    @sort_direction || 'desc'
  end

  def sortable_header_link(nice_name, sort_name, path, table_name='table.advisor_listing', addtl_class='')
    content_tag( :th,
                 link_to_function(nice_name, %[sort_table("#{table_name}", "#{sort_name}", "#{path}")]),
                 :class => "sorted #{sort_by == sort_name ? sort_direction : ''} #{addtl_class}")
  end

  def header_logo
    return link_to(content_tag(:h1, account_business_name), root_path) if current_account.header_image.blank?
    return link_to(image_tag(current_account.header_image, :size => "408x59",  :style => 'border:0', :alt => "#{account_business_name} Home"), root_path)
  rescue
    return link_to(image_tag('logos/generic.jpg'), '/')
  end

  def environment_tag
  # Used to place a notice at the top of the app when not in production environment
    environment = case RAILS_ENV
      when 'staging': content_tag(:div, "Staging: #{current_user.display_name}", :class => "environment_notice")
      when 'development': content_tag(:div, "Development: #{current_user.display_name}", :class => "environment_notice")
    end
  end

  def flash_notices
    [:notice, :error].collect {|type| content_tag('div', flash[type], :id => type) if flash[type] }
  end

  # Render a submit button and cancel link
  def submit_or_cancel(cancel_url = session[:return_to] ? session[:return_to] : url_for(:action => 'index'), label = 'Save Changes')
    content_tag(:div, submit_tag(label, :class => "btTxt button left fg-button ui-state-default ui-priority-primary ui-corner-all create_button submit_or_cancel_offset", :id => 'submit_button') + ' or ' +
      link_to('Cancel', cancel_url), :id => 'submit_or_cancel', :class => 'submit')
  end


  def display_standard_flashes(message = 'There were some problems with your submission:')
    if flash[:notice]
      # raise flash[:notice].inspect
      flash_to_display, level = flash[:notice], 'notice'
    elsif flash[:warning]
      flash_to_display, level = flash[:warning], 'warning'
    elsif flash[:error]
      level = 'error'
      if flash[:error].instance_of?(ActiveRecord::Errors) || flash[:error].is_a?( Hash)
        flash_to_display = message
        flash_to_display << activerecord_error_list(flash[:error])
      else
        flash_to_display = flash[:error]
      end
    else
      return
    end
    content_tag 'div', flash_to_display, :class => "flash#{level}"
  end

  def activerecord_error_list(errors)
    error_list = '<ul class="error_list">'
    error_list << errors.collect do |e, m|
      "<li>#{e.humanize unless e == "base"} #{m}</li>"
    end.to_s << '</ul>'
    error_list
  end

  def activerecord_error_list2(errors)
    errors.map do |e, m|
      "#{e.humanize unless e == "base"} #{m}\n"
    end.to_s.chomp
  end

  def account_business_name
    current_account.name rescue ''
  end

  def brokerage_account_business_name
    current_account.brokerage_name rescue ''
  end

  def short_brokerage_account_business_name
    current_account.short_brokerage_name rescue ''
  end

  def account_subdomain
    current_account.full_domain.split(".")[0]
  end

  def account_brokerage_subdomain
    current_account.full_broker_domain.split(".")[0]
  end

  def set_titles(title = nil)
    env = {"development" => "(DEV)", "staging" => "(STAGING)"}[Rails.env] || ''
    head_title = title ? "#{title} -" : ''
    @page_title ||= title
    @head_title ||= "#{env} #{head_title} #{h account_business_name} StatusRoom".squeeze(' ').strip
  end

  def sub_menu
    raise controller.template_root
    begin
      render :partial => 'menu'
    rescue
      '<div id="section_menu"></div>'
    end
  end

  def body_classes
    # Used for setting css navigation tabs correctly
    @controller.request.path.split('/') * ' '
  end

  def main_tab
    @controller.request.path.split('/')[1] rescue 0
  end

  def main_menu
    content = sitemap.items.inject('') do |content, menu|
      href, klass = menu.selected? ? [menu.link, "<li class='current'>"] : [menu.link, "<li>"]
      content << "\n#{klass}<a href='#{href}'><span>#{menu.label}</span></a></li>"
      content
     end
    return content_tag(:ul, content, :id => "nav")
  end

  def nav_tab(level, path, name)
    content = "<li#{request.path.eql?(path) ? " class='menu#{level}-tabs-selected'": nil}><a href='#{path}'><span>#{name}</span></a></li>"
  end

  def reg_symbol
    "<sup class='reg_symbol'>&reg;</sup>"
  end

  def tm_symbol
    "<sup class='tm_symbol'>&trade;</sup>"
  end

  def user_image(advisor, options={:alt => '', :size=>'medium'})
    if advisor.image.blank?
      image_tag '/images/advisors/notavailable.png', ({:alt => ''}).merge(options)
    else
      options.merge({:alt => "#{advisor.display_name} Image"}) if options[:alt] != ''
      image_tag(url_for_file_column(advisor, 'image', options[:size]), options)
    end
  end

  def producer_share_percentage(share)
    share = share.blank? ? 0 : share
    "(#{number_to_percentage(share, :precision => 0)})"
  end

  def producer_share_percentage_and_amount(share, amount)
    share = share.blank? ? 0 : share
    "(#{number_to_percentage(share, :precision => 0)}/#{number_to_currency((share.to_f/100) * amount, :precision => 0)})"
  end


  def clubcredits_status(who)
    tooltip_label = "Advisor" if who.is_a?(User)
    tooltip_label = "Unit"    if who.is_a?(Team)
    tooltip_label = "Agency"  if who.is_a?(Account)
    yearly_performance = who.overall_clubcredits_performance
    up_or_down, last_years_performance, comp_last_year_performance = who.clubcredits_compared_to_last_year()
    plus_minus = up_or_down == :down ? "-" : "+"
    plus_minus = up_or_down == :down ? "-" : "+"
    title_tooltip = "#{tooltip_label} Club Credits YTD Total is #{number_to_currency(yearly_performance, :precision => 0)} which is #{up_or_down.to_s} #{number_to_percentage(last_years_performance*100, :precision => 1) rescue '-'} from the #{number_to_currency(comp_last_year_performance, :precision => 0)} it was this time last year."
    html = "Total Club Credits: "
    html << content_tag(:strong, number_to_currency(yearly_performance, :precision => 0))
    html << "\n"
    html << image_tag("/images/icons/#{up_or_down}.png")
    html << "\n"
    html << content_tag(:span, "#{plus_minus}#{number_to_percentage(last_years_performance*100, :precision => 1) rescue '-'}", :class => 'tooltip tooltip_underline', :title => title_tooltip)
    html
  end

  def advisor_clubcredits_status(advisor)
    yearly_performance = advisor.overall_clubcredits_performance
    up_or_down, last_years_performance, comp_last_year_performance = advisor.clubcredits_compared_to_last_year()
    plus_minus = up_or_down == :down ? "-" : "+"
    plus_minus = up_or_down == :down ? "-" : "+"
    title_tooltip = "Advisor Club Credits YTD Total is #{number_to_currency(yearly_performance, :precision => 0)} which is #{up_or_down.to_s} #{number_to_percentage(last_years_performance*100, :precision => 1) rescue '-'} from the #{number_to_currency(comp_last_year_performance, :precision => 0)} it was this time last year."
    html = "Total Club Credits: "
    html << content_tag(:strong, number_to_currency(yearly_performance, :precision => 0))
    html << "\n"
    html << image_tag("/images/icons/#{up_or_down}.png")
    html << "\n"
    html << content_tag(:span, "#{plus_minus}#{number_to_percentage(last_years_performance*100, :precision => 1) rescue '-'}", :class => 'tooltip tooltip_underline', :title => title_tooltip)
    html
  end

  def advisor_target_status(advisor, label, goal)
    html = " #{label} "
    target_status = advisor.on_track_for_goal?(@year_num, goal)
    html << content_tag(:strong, number_to_currency(goal, :precision => 0))
    html << "\n"
    html << target_arrow(advisor, goal)
    html
  end

  def target_status(who, label, goal)
    html = " #{label} "
    target_status = who.on_track_for_goal?(@year_num, goal)
    html << content_tag(:strong, number_to_currency(goal, :precision => 0))
    html << "\n"
    html << target_arrow(who, goal)
    html
  end

  def advisor_premium_goal_status(advisor, label, goal)
    html = " #{label} "
    target_status = advisor.on_track_for_premiums?(@year_num, goal)
    html << content_tag(:strong, number_to_currency(goal, :precision => 0))
    html << "\n"
    html << target_arrow(advisor, goal, :on_track_for_premiums?)
    html
  end


  def target_arrow(advisor, goal, metric = :on_track_for_goal?)
    mesg = "Goal is #{number_to_currency(goal, :precision => 0)}"
    polarity = advisor.send(metric, @year_num, goal) == :below ? 'down' : 'up'
    image_tag("/images/v2/icons/#{polarity}.png", :alt => mesg, :title => mesg)
  end


  def apr_status_indicator(advisor, period_month = nil, period_year = nil)
    if period_month.nil? || period_year.nil?
      status = advisor.apr_status.blank? ? "not_found" : advisor.apr_status
    else
      logger.info "!!!!!!!!!! Month: #{period_month}. Year: #{period_year}"
      status = AprStatus.find_by_user_id_and_period_month_and_period_year(advisor.id, period_month, period_year).name
    end
    status = "not_found" if status.blank?
    image_tag "icons/#{status}.png"
  end

  def apr_status_indicator_from_text(period_status = "")
    status = period_status.blank? ? "not_found" : period_status.strip.downcase.gsub(" ","_")
    image_tag "icons/#{status}.png"
  end


  def two_months_past(m = Time.now.month, y = Time.now.year)
    case m
    when 1
      "#{MONTHS[10]} #{y-1}"
    when 2
      "#{MONTHS[11]} #{y-1}"
    else
      "#{MONTHS[m-3]} #{y}"
    end
  end

  def one_month_past(m = Time.now.month, y = Time.now.year)
    case m
    when 1
      "#{MONTHS[11]} #{y-1}"
    else
      "#{MONTHS[m-2]} #{y}"
    end
  end

  def dashboard_notice(m = Time.now.month, y = Time.now.year)
    case m
    when 1
      html = "<div class='notice right'>Happy New Year. "
      html << link_to("Last Month's Dashboard (#{MONTHS[11]} #{y-1})", dashboard_history_path(:m => 12, :y => y-1), :title => "Dashboard History", :alt => "Dashboard History")
      html << "</div>"
    else
      html = "<div class='notice right'>"
      html << link_to("Last Month's Dashboard (#{MONTHS[m-2]} #{y})", dashboard_history_path(:m => m-1, :y => y), :title => "Dashboard History", :alt => "Dashboard History")
      html << "</div>"
    end
  end

#----------------------------------------------------------------------------
# Breadcrumb Helpers

  def display_crumbs
    drop_crumbs if @breadcrumbs.nil?
    html = "<div class='breadCrumbHolder module' style='background:#333'><div id='breadCrumbMainNav' class='breadCrumb module'><ul>"
    @breadcrumbs[0..-2].each do |text, path|
      html << content_tag(:li, link_to(h(text), path))
    end
    html << content_tag(:li, h(@breadcrumbs.last.first))
    html << "</ul></div><div class='chevronOverlay main'></div></div>"

    #  jQuery Breadcrumb sample html/haml:
    #
    #     .breadCrumbHolder.module{:style => "background:#333"}
    #       #breadCrumb0.breadCrumb.module
    #         %ul
    #           %li
    #             %a{ :href => "#" } Dashboard
    #           %li
    #             %a{ :href => "#" } Producers
    #           %li
    #             %a{ :href => "#" } Brian Kirk
    #           %li
    #             %a{ :href => "#" } Cases
    #           %li
    #             %a{ :href => "#" } Wang2010003023
    #           %li Overview
    #       .chevronOverlay.main

  end

  # Append one or more crumbs
  def drop_crumbs(*args)
    @breadcrumbs ||= []
    args = [request.path] if args.empty?
    args.each do |crumb|
      crumbs = make_crumb(crumb)
      if crumbs[0].instance_of? Array
        @breadcrumbs = @breadcrumbs | crumbs
      else
        @breadcrumbs << crumbs
      end
    end
  end

  def calculate_working_days(d1,d2)
    if d1.blank? || d2.blank?
      return "-"
    else
      weekdays = (d1..d2).reject { |d| [0,6].include? d.wday }
      weekdays.length
    end
  end

  def link_to_add_fields(name, f, association)
    new_object = f.object.class.reflect_on_association(association).klass.new
    fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render(association.to_s.singularize + "_fields", :f => builder)
    end
    link_to_function(name, h("add_fields(this, \"#{association}\", \"#{escape_javascript(fields)}\")"))
  end

  def display_value(field)
    field.blank? ? " - " : field
  end

  # def validate_date(arg)
  #   case arg.class
  #   when Date
  #     arg
  #   when Time
  #     arg
  #   when String
  #     begin
  #       arg = Date.parse(arg)
  #     rescue ArgumentError => e
  #       puts("Invalid date parameter was passed. Error: #{e}")
  #       false
  #     end
  #   end
  # end



  def ensure_valid_date(arg)
    begin
      arg = arg.to_date
    rescue Exception => e
      logger.error e, e.backtrace
      false
    end
  end

#----------------------------------------------------------------------------
# End of Month Cutoff Date Helpers
#   The following methods rely on the business_time gem
#   for '.workday?', 'business_days.before' & 'business_days_until'
#   Business cutoff is CUTOFF_OFFSET business days before the last business day of the month

  CUTOFF_OFFSET = 2 # GLIC cutoff date is 2 business days before last business day of month
  DAYS_PRIOR_TO_ALERT = 5 # Set alert class on html so many days prior to cutoff date

  def last_business_day_of_month(year = Date.today.year, month = Date.today.month)
    last_day_of_month = Date.civil(year, month, -1)
    @offset = 0
    until (last_day_of_month - @offset).workday?
      @offset += 1
    end
    last_day_of_month - @offset
  end

  def eom_cutoff_date(year = Date.today.year, month = Date.today.month)
    last_business_day = last_business_day_of_month(year, month)
    @offset = 0
    until (CUTOFF_OFFSET.business_days.before(last_business_day).to_date - @offset).workday?
      @offset += 1
    end
    CUTOFF_OFFSET.business_days.before(last_business_day).to_date - @offset
  end

  def business_days_until_eom_cutoff(date = Date.today)
    return -1 unless (date = ensure_valid_date(date))
    date.business_days_until(eom_cutoff_date(date.year, date.month))
  end

  def describe_eom_cutoff_status(date = Date.today)
    return "" unless (date = ensure_valid_date(date))
    remaining_days = business_days_until_eom_cutoff(date)
    if date == eom_cutoff_date
      "<span class='alert'>Today is home office month-end cutoff (#{eom_cutoff_date(date.year, date.month)}).</span>"
    elsif remaining_days == 0
      "There are no business days remaining until home office month-end cutoff (#{eom_cutoff_date(date.year, date.month)})."
    elsif remaining_days == 1
      "<span class='alert'>There is only #{remaining_days} business day remaining until home office month-end cutoff (#{eom_cutoff_date(date.year, date.month)}).</span>"
    elsif remaining_days <= DAYS_PRIOR_TO_ALERT
      "<span class='alert'>There are only #{remaining_days} business days remaining until home office month-end cutoff (#{eom_cutoff_date(date.year, date.month)}).</span>"
    else
      "There are #{remaining_days} business days remaining until home office month-end cutoff (#{eom_cutoff_date(date.year, date.month)})."
    end
  end

# / End of Month Cutoff Helpers
#----------------------------------------------------------------------------

  private

  # Returns a crumb array like ['Home', '/']
  def make_crumb(crumb)
    return ['Home', '/'] if crumb.empty?
    if crumb.instance_of? String
      break_off_crumbs(crumb)
    elsif crumb.instance_of? Array
      return crumb if crumb.size > 1
      return ['Home', '/'] if crumb[0].empty?
      title = crumb[0].split('/').last.split(/_|\s/).each { |word| word.capitalize! }.join(' ') unless crumb[0].nil?
      [title, crumb[0]]
    end
  end

  # Break a uri into an array of crumbs
  def break_off_crumbs(uri)
    crumbs = []
    split_uri = uri.split('/')
    split_uri.each_with_index do |crumb, i|
      crumbs << make_crumb([split_uri[0..i].join('/')])
    end
    crumbs
  end

  def display_apr_status_totals(year, month)
    if month == 12
      statuses = %w[qualified not_qualified]
    else
      statuses = %w[qualified on_target not_on_target]
    end
    html = "<div id='apr_status_totals'>"
    statuses.each do |status_type|
      html << image_tag("/images/icons/#{status_type}.png", :class => 'apr_icon')
      html << "<span class='apr_number'>"
      html << AprStatus.total_for_period_by_type(year, month, status_type).to_s rescue "-"
      html << "</span>"
    end
    html << "</div>"
    html
  end

  def small_case_name_with_icon(sale_case)
    policy_type = sale_case.policy_type.nil? ? '' : sale_case.policy_type

    icon_type = {'Life' => 'life', 'DI' => 'di', 'LTC' => 'ltc', 'WLife' => 'windsor', 'Info' => 'info' }[policy_type] || 'unk' rescue 'unk'
    # icon_type = sale_case.policy_type.nil? ? 'unk' : {'Life' => 'life', 'DI' => 'di', 'LTC' => 'ltc' }[sale_case.policy_type] || 'unk'
    title = "#{policy_type} Case ##{sale_case.case_name}"
    link_text = content_tag(:span, truncate(sale_case.case_name, :length => 18), :class => 'case_mini_name')
    link_text << content_tag(:span, truncate(sale_case.insured_last_name + ", " + sale_case.insured_first_name, :length => 18), :class => 'case_mini_client')
    html = "<div class='case_mini_block'>"
    html << image_tag("/images/icons/case_icon_#{icon_type}_16.jpg", :size => '16x16', :title => "#{title}", :class => 'case_icon_16')
    html << link_to(link_text, sale_case, :title => title, :alt => title)
    html << "</div>"
  end

  def case_icon(sale_case, size=32)
    icon_type = {'Life' => 'life', 'DI' => 'di', 'LTC' => 'ltc', 'WLife' => 'windsor', 'Info' => 'info' }[sale_case.policy_type] || 'unk'
    title = "#{sale_case.policy_type} Case ##{sale_case.case_name}"
    image_tag("/images/icons/case_icon_#{icon_type}_#{size}.jpg", :size => "#{size}x#{size}", :title => "#{title}", :class => "case_icon_#{size}")
  end

  def permission_icon(granted=false, size=16)
    if granted
      icon_type = 'granted'
      title = 'Permission Granted'
    else
      icon_type = 'denied'
      title = 'Permission Denied'
    end
    html = content_tag(:span, granted ? '1' : '0', :style => 'display:none')
    html << image_tag("/images/icons/permission_icon_#{icon_type}_#{size}.png", :size => "#{size}x#{size}", :title => "#{title}", :class => "permission_icon_#{size}")
  end

  # For deferring execution of js until after framework load (at the bottom of html)
  def deferred(&block)
    @deferred_content ||= ""
    @deferred_content << capture(&block)
  end

  def date_for_sorting(date)
    date.strftime('%Y%m%d%H%M%S')
  end

  def remove_child_link(name, f, options = {})
    html = f.hidden_field(:_destroy)
    html + link_to(name, "javascript:void(0)", :class => "remove_child")
  end

  def add_child_link(name, association, options = {})
    html = link_to(name, "javascript:void(0)", :class => "add_child", :"data-association" => association)
    html
  end

  def new_child_fields_template(form_builder, association, options = {})
    options[:object] ||= form_builder.object.class.reflect_on_association(association).klass.new
    options[:partial] ||= "new_" + association.to_s.singularize
    options[:form_builder_local] ||= :f

  #  content_tag(:div, :id => "#{association}_fields_template", :style => "display: none;") do
      form_builder.fields_for(association, options[:object], :child_index => "new_#{association}") do |f|
        render(:partial => options[:partial], :locals => {options[:form_builder_local] => f})
      end
 #   end
  end

  # = link_to_add_fields "Add a Producer", f, :sale_case_shares
  def link_to_add_fields(name, f, association)
    new_object = f.object.class.reflect_on_association(association).klass.new
    fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render(association.to_s.singularize + "_fields", :f => builder)
    end
    link_to_function(name, h("add_fields(this, \"#{association}\", \"#{escape_javascript(fields)}\")"))
  end

  # Borrowed in haste and adapted from: http://www.tsdbrown.com/2010/06/07/create-multiple-records-for-one-model-in-rails
  def remove_record_link(link_text)
    # link_to(link_text, "javascript:void(0)", :class => "remove_record")
    link_to "#{content_tag(:span, '', :class => 'ui-icon ui-icon-circle-minus')} #{link_text}", "javascript:void(0)", :class => "fg-button fg-button-icon-left ui-state-default ui-corner-all remove_record"
  end

  def add_record_link(link_text, model)
    # link_to(link_text, "javascript:void(0)", :class => "add_record", :"data-model" => model.downcase)
    link_to "#{content_tag(:span, '', :class => 'ui-icon ui-icon-circle-plus')} #{link_text}", "javascript:void(0)", :class => "fg-button fg-button-icon-left ui-state-default ui-corner-all add_record", :"data-model" => model.downcase
  end

  def new_fields_template(model, options = {})
    options[:object]  ||= Object.const_get(model).new
    lowercase_model_name = model.downcase
    options[:partial] ||= lowercase_model_name

    content_tag(:div, :id => "#{lowercase_model_name}_fields_template", :style => "display: none") do
      semantic_fields_for("#{lowercase_model_name.pluralize}[new-id-here]", options[:object]) do |f|
        render(:partial => options[:partial], :locals => {:f => f, :offer_remove => true})
      end
    end
  end

  def random_brokerage_image
    image_files = %w( .jpg .gif .png )
    files = Dir.entries(
      "#{RAILS_ROOT}/public/images/brokerage/rotate"
    ).delete_if { |x| !image_files.index(x[-4,4]) }
    files[rand(files.length)]
  end

  def last_premium_updated_date
    Premium.last.created_at.strftime('%b %d, %Y - %I:%M %p')
  end

  def messages_header_link
    if current_user.has_new_messages?
      messages_text = "Messages (" + current_user.new_messages.length.to_s + ")"
      link_to messages_text, message_center_messages_path, :class => 'alert'
    else
      link_to "Messages", message_center_messages_path
    end
  end

  def user_name_header
    if @user.is_producer?
      if @user.is_broker?
        producer_label = "Broker"
      else
        producer_label = "Contracted #{@user.contract_type}"
      end
    end

    html = "Profile: #{@user.display_name}"
    if @user.is_producer?
      html << " <span class='case_header_producer'>| #{producer_label}</span>"
    end
    html << "\n"

  end

  def display_formatted_currency_for_datatable(value)
    amount = value.to_f
    # html = ""
    case
    when amount > 0
      number_to_currency(amount, :precision => 2)
      # html << "<span class='standout'>#{number_to_currency(amount, :precision => 2)}</span>"
    when amount < 0
      number_to_currency(amount, :precision => 2)
    else
      number_to_currency(amount, :precision => 0)
    end
  end

  def guardian_mfa_challenges
    ["What was your childhood nickname?",
      "What school did you attend for sixth grade?",
      "What is the name of your first pet?",
      "Who was the maker of your first car?",
      "What is the middle name of your oldest sibling?",
      "What is your paternal grandfather's first name?",
      "What is your maternal grandmother's first name?",
      "What is your father's middle name?",
      "What is your mother's middle name?",
      "In what city does your nearest sibling live?",
      "What is the name of your high school best friend?",
      "What is the middle name of your youngest sibling?",
      "What is the first name of your spouse's father?",
      "What is the first name of the person you went to your prom with?",
      "How old was your father when you were born, spell out number?",
      "What is your spouse's middle name?",
      "In what city or town did your mother and father meet?",
      "What was your high school mascot?",
      "What street did you live on when you were born?",
      "What was the color of your first car?"
    ]
  end

  def guardian_mfa_challenges_select(selected_challenge)
    html = ""
    challenges = guardian_mfa_challenges
    challenges.each do |challenge|
      html << "<option value='#{challenge}'#{' selected=1' if challenge==selected_challenge}>#{challenge}</option>"
    end
  end

end
