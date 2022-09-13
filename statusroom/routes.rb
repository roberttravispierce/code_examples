ActionController::Routing::Routes.draw do |map|
  map.resources :user_attachments


  map.root :controller => 'dashboard', :action => 'redirect'

#----------------------------------------------------------------------------
# Dashboard Routes
  map.dashboard_history '/dashboard/:y/:m', :controller => 'dashboard', :action => 'history'
  map.dashboard_year    '/dashboard/:y',    :controller => 'dashboard', :action => 'full_year'
  map.dashboard         '/dashboard',       :controller => 'dashboard', :action => 'index'
  # map.performance_dashboard '/peformance_dashboard',   :controller => 'dashboard', :action => 'performance_dashboard'
  map.production_summary '/production_summary',   :controller => 'dashboard', :action => 'production_summary'
  map.nbu 'nbu', :controller => 'dashboard', :action => 'nbu'

#----------------------------------------------------------------------------
# Case Management Routes
  map.sale_cases_reference '/cases/reference', :controller => 'sale_cases', :action => 'reference'
  map.resources :sale_cases,
                :as => 'cases',
                :has_many => :sale_case_attachments,
                :collection =>  { :list => :any,
                                  :pending => :any,
                                  :state => :any,
                                  :summary_list => :any,
                                  :search => :any,
                                  :supervisor => :any,
                                  :search_supervisors => :any,
                                  :quick_search => :any,
                                  :paid => :any, :paid_list => :any,
                                  :my_cases => :any,
                                  :my_unknown_cases => :any,
                                  :windsor_list => :any,
                                  :recently_paid => :any,
                                  :inp => :any,
                                  :staff => :any,
                                  :executive => :any,
                                  :producer => :any,
                                  :team => :any,
                                  :agency => :any,
                                  :ctm_targeted => :any,
                                  :has_outstanding_requirements => :any,
                                  :transitions => :any,
                                  :metrics => :any
                                },
                :member => {:case_details_view => :any, :link => :put, :update_state => :post, :current_status => :get, :guardian_view => :any, :forecast_view => :any, :clone => :any } do |sale_case|
                  sale_case.resources :forecasts, :shallow => false
                  sale_case.resources :notes, :collection => {:no_access => :get}, :member => {:notes_view => :any}
                  sale_case.resources :sale_case_attachments, :collection=>{:create_for_case => :any}, :member=>{:attachments_view => :any}
                  sale_case.resources :policy_events
                  sale_case.resources :messages, :collection => { :messages_view => :get }
                  sale_case.resources :requirements,
                        :shallow => false,
                        :member => {
                          :requirement_edit_view => :get
                        },
                        :collection => {
                          :requirements_view => :get
                        }
  end

  map.resources :supervisors
  map.resources :unit_managers

  map.request_info 'request_info', :controller => 'sale_cases', :action => 'broker_info_request'

  map.resources :requirements,
                    :has_many => :notes,
                    :collection => {
                      :sst_requirements => :get
                    }

  map.resources :sale_case_relationships

  map.resources :guardian_people

  map.sale_case_forecast_history '/case/:id/forecasts', :controller => 'sale_case', :action => 'history'

  # TODO: Temp hookup until cleanup and/or consolidation in controller
  map.sale_cases_all_stages '/cases/all_stages', :controller => 'sale_case', :action => 'cases_by_stage'

  map.producer_my_cases '/performance/producer/:advisor_id/cases', :controller => 'sale_cases', :action => 'my_producer_cases'
  map.my_requirements '/cases/requirements/my_requirments', :controller => 'requirements', :action => 'my_requirements'

#----------------------------------------------------------------------------
# Data Management Routes
  map.data_status '/admin/status',                          :controller => 'data', :action => 'status'
  map.data_import '/data/import',                           :controller => 'data', :action => 'import'
  map.data_import_frfsall '/data/import/frfsall',           :controller => 'data', :action => 'import_frfsall'
  map.data_import_eap '/data/import/eap',                   :controller => 'data', :action => 'import_eap'
  map.data_import_gdc '/data/import/gdc',                   :controller => 'data', :action => 'import_gdc'
  map.data_merge_users '/data/merge_users',                 :controller => 'data', :action => 'merge_users'
  map.data_delete_merged_users '/data/delete_merged_users', :controller => 'data', :action => 'delete_merged_users'
  map.import_clubsumm '/performance/clubsumm-reports',      :controller => 'accounts', :action => 'import_reports'

  map.admin       '/admin',                  :controller => 'users', :action => 'index'
  map.register    '/register',               :controller => 'users', :action => 'register'
  map.create_broker '/create_broker',        :controller => 'users', :action => 'create_broker'
  map.signed_up   '/signed_up/:code',        :controller => 'users', :action => 'signed_up'
  map.activate    '/activate/:code',         :controller => 'users', :action => 'activate'
  map.login       '/login',                  :controller => 'sessions', :action => 'new'
  map.logout      '/logout',                 :controller => 'sessions', :action => 'destroy'
  map.active '/active', :controller => 'sessions', :action => 'active'
  map.timeout '/timeout', :controller => 'sessions', :action => 'timeout'
  map.login_help  '/login_help',             :controller => 'sessions', :action => 'help'
  map.audit_log   '/admin/logs',             :controller => 'footprints', :action => 'log'
  map.footprint   '/admin/logs/detail/:id',  :controller => 'footprints', :action => 'show'
  map.resources :forecasts
  map.resources :notes, :path_prefix => "admin", :collection=>{:no_access => :get, :create_for_case => :any}, :member=>{:access_level => :post}
  map.resources :sale_case_attachments, :collection=>{:create_for_case => :any}, :member=>{:access_level => :post, :attachments_view => :any}
  map.resources :policy_events, :path_prefix => "policies" do |policy_event|
    policy_event.resources :notes
  end
  map.premiums '/performance/premiums', :controller => 'premiums', :action => "summary"
  map.premiums_listing '/performance/premiums/:action', :controller => 'premiums'
  map.advisor_policies '/policies/by-advisor/:advisor_id', :controller => 'policies', :action => 'index'
  map.advisor_policies_by_status '/policies/by-advisor/:advisor_id/:status', :controller => 'policies', :action => 'index'
  map.new_business '/policies', :controller => 'policies', :action => 'index'
  map.policies_by_status '/policies/status/:status', :controller => 'policies', :action => 'index'
  map.policy_forecast_history '/policy/:id/history', :controller => 'policy', :action => 'history'
  map.resources :policies, :shallow => true, :member => {:history => :get}, :collection => {:search => :get} do |policy|
    policy.resources :forecasts, :shallow => false
    policy.resources :notes, :collection=>{:no_access => :get}
    policy.resources :policy_events
    policy.resources :requirements, :shallow => false, :except => :show
  end
  map.resources :requirements, :only => [], :collection => { :for_user => :get }

  map.agency_advisor_premium_list   '/performance/agency/advisor-premium-list', :controller => 'agency', :action => 'advisor_premium_list'
  map.agency_advisor_premium_list_bkr   '/performance/agency/advisor-premium-list-bkr', :controller => 'agency', :action => 'advisor_premium_list_bkr'
  map.agency_advisor_premium_list_fp   '/performance/agency/advisor-premium-list-fp', :controller => 'agency', :action => 'advisor_premium_list_fp'
  map.agency_advisor_premium_list_fr   '/performance/agency/advisor-premium-list-fr', :controller => 'agency', :action => 'advisor_premium_list_fr'
  map.agency_advisor_premium_list_frfpfta   '/performance/agency/advisor-premium-list-frfpfta', :controller => 'agency', :action => 'advisor_premium_list_frfpfta'
  map.agency_advisor_premium_list_bkrfpfta   '/performance/agency/advisor-premium-list-bkrfpfta', :controller => 'agency', :action => 'advisor_premium_list_bkrfpfta'
  map.agency_advisor_premium_list_frsa   '/performance/agency/advisor-premium-list-frsa', :controller => 'agency', :action => 'advisor_premium_list_frsa'
  map.agency_advisor_premium_list_fta   '/performance/agency/advisor-premium-list-fta', :controller => 'agency', :action => 'advisor_premium_list_fta'
  map.agency_advisor_premium_list_mgr   '/performance/agency/advisor-premium-list-mgr', :controller => 'agency', :action => 'advisor_premium_list_mgr'
  map.agency_advisor_premium_list_fmr   '/performance/agency/advisor-premium-list-fmr', :controller => 'agency', :action => 'advisor_premium_list_fmr'
  map.agency_advisor_premium_list_not_on_target   '/performance/agency/advisor-premium-list-not-on-target', :controller => 'agency', :action => 'advisor_premium_list_not_on_target'
  map.agency_advisor_premium_list_on_target   '/performance/agency/advisor-premium-list-on-target', :controller => 'agency', :action => 'advisor_premium_list_on_target'
  map.agency_advisor_premium_list_qualified   '/performance/agency/advisor-premium-list-qualified', :controller => 'agency', :action => 'advisor_premium_list_qualified'
  map.agency_advisor_premium_list_sa   '/performance/agency/advisor-premium-list-sa', :controller => 'agency', :action => 'advisor_premium_list_sa'
  map.agency_advisor_premium_list_all   '/performance/agency/advisor-premium-list-all', :controller => 'agency', :action => 'advisor_premium_list_all'

  # map.agency_advisor_club_list      '/performance/agency/advisor-club-list', :controller => 'agency', :action => 'advisor_club_credits_list'
  map.club_credits_list             '/:controller/club-credits-list', :action => 'club_credits_list'

  map.agency                        '/performance/agency', :controller => 'agency', :action => 'show'
  map.agency_cases                  '/performance/agency/cases', :controller => 'agency', :action => 'cases'
  map.formatted_agency              '/performance/agency.:format', :controller => 'agency', :action => 'show'
  map.setup_agency_performance      '/performance/agency/setup', :controller => 'agency', :action => 'setup_targets'
  map.agency_summary                '/performance/agency/:tab', :controller => 'agency', :action => 'summary'

  # map.account_sale_cases '/performance/agency', :controller => 'agency', :action => 'cases'

#----------------------------------------------------------------------------
# Units/Teams Routes

  map.resources :teams,
                :path_prefix => "performance",
                :collection =>  {
                                  :report => :get,
                                  :list => :any,
                                  :list_with_premium => :get
                                },
                :member =>      {
                                  :add_member_to => [:get, :post],
                                  :remove_member_from => [:get,:post]
                                }
  map.team_cases                '/performance/teams/:team_id/cases', :controller => 'teams', :action => 'cases'
  # map.team_new_business         '/performance/teams/:team_id/policies', :controller => 'policies', :action => 'index'
  map.team_summary              '/performance/teams/:id/:tab', :controller => 'teams', :action => 'summary'

#----------------------------------------------------------------------------
# Producers (old: Advisors)

  map.resources :producers,
                :collection => { :search => :any, :list => :any },
                :member => { :dialog_show => :any }

  #TODO: Move these over to producers controller
  map.resources :advisors, :path_prefix => 'producers',
                :collection =>  { :list => :get }

#----------------------------------------------------------------------------
# Reports

  map.club_qualification_report     '/reports/club_qualification', :controller => 'club_reports', :action => 'club_qualification'

#----------------------------------------------------------------------------

  map.advisor_search                '/advisors/search', :controller => 'advisors', :action => 'search'
  map.advisors_performance          '/performance/advisors', :controller => 'advisors', :action => 'listing'
  map.clubsumm_report               '/performance/advisors/clubsumm', :controller => 'club_reports', :action => "index"
  map.advisor_performance           '/performance/advisors/:id', :controller => 'advisors', :action => 'performance'
  map.advisor_summary_tab           '/producers/advisors/:id/summary/:tab', :controller => 'advisors', :action => 'show'
  map.advisor_new_business          '/performance/advisors/:advisor_id/policies', :controller => 'policies', :action => 'index'
  map.advisor_reports               '/performance/advisors/:advisor_id/reports', :controller => 'reports', :action => 'index'
  map.advisor_report                '/performance/advisors/:advisor_id/reports/:id', :controller => 'reports', :action => 'show'

  map.advisor_gdc                   '/performance/advisors/:advisor_id/gdc', :controller => 'gdc', :action => 'advisor'
  map.with_options :controller => 'charts' do |chart|
    chart.clubsumm_chart          '/charts/clubsumm.xml', :action => 'clubsumm', :format => 'xml'
    chart.clubsumm_details_chart  '/charts/clubsumm-details.xml', :action => 'clubsumm_details', :format => 'xml'

    chart.agency_premiums_chart   '/charts/agency/premiums.:format',               :action => 'premiums'
    chart.advisor_premiums_chart  '/charts/advisor/:advisor_id/premiums.:format',  :action => 'premiums'
    chart.team_premiums_chart     '/charts/team/:team_id/premiums.:format',        :action => 'premiums'
    # Premiums Charts
    chart.with_options :action => 'premiums_for_month' do |pfm|
      pfm.advisor_premiums_month_chart '/charts/advisor/:advisor_id/premiums-for-month.:format'
      pfm.team_premiums_month_chart    '/charts/team/:team_id/premiums-for-month.:format'
      pfm.agency_premiums_month_chart '/charts/agency/premiums-for-month.:format'
    end
    # Premiums Charts for quarter
    chart.with_options :action => 'premiums_by_category_for_quarter' do |mp|
      mp.advisor_premiums_quarter_by_category '/charts/advisor/:advisor_id/premiums-by-category-for-quarter.:format'
      mp.team_premiums_quarter_by_category    '/charts/team/:team_id/premiums-by-category-for-quarter.:format'
      mp.agency_premiums_quarter_by_category '/charts/agency/premiums-by-category-for-quarter.:format'
    end
    # Premiums Charts for month
    chart.with_options :action => 'premiums_by_category_for_month' do |mp|
      mp.advisor_premiums_month_by_category '/charts/advisor/:advisor_id/premiums-by-category-for-month.:format'
      mp.team_premiums_month_by_category    '/charts/team/:team_id/premiums-by-category-for-month.:format'
      mp.agency_premiums_month_by_category '/charts/agency/premiums-by-category-for-month.:format'
    end
    chart.agency_club_runrate_chart    '/charts/company/:category.:format',        :action => 'agency_club_runrate'
    chart.advisor_clubsumm_chart       '/charts/advisor/:id/clubsumm.:format',     :action => 'advisor_clubsumm'
    chart.advisor_premiums_by_category '/charts/advisor/:advisor_id/premiums-by-category.:format', :action => 'premiums_by_category'
    chart.agency_clubsumm_by_category  '/charts/agency/clubsumm-by-category.:format', :action => 'agency_clubsumm_by_category'
    chart.agency_premiums_by_category  '/charts/agency/premiums-by-category.:format', :action => 'premiums_by_category'
    chart.team_premiums_by_category    '/charts/team/:team_id/premiums-by-category.:format', :action => 'premiums_by_category'
    chart.advisor_chart                '/charts/advisor/:id/:category.:format',    :action => 'advisor_run_rate'
    chart.team_clubsumm_chart          '/charts/team/:id/clubsumm-by-category.:format',    :action => 'team_clubsumm_by_category'
    chart.unit_runrate_chart           '/charts/team/:id/:category.:format',       :action => 'unit_run_rate'
    chart.top_performers_chart         '/charts/top-performers.:format',           :action => 'top_performers'
  end

#----------------------------------------------------------------------------
# Account Routes

  map.resource :account,  :collection => {
                            :dashboard => :get,
                            :thanks => :get,
                            :plans => :get,
                            :billing => :any,
                            :plan => :any,
                            :cancel => :any,
                            :canceled => :get
                          }


#----------------------------------------------------------------------------
# User Routes

  map.resources :users, :collection => {
                          :nbu_create_broker => :post,
                          :password_reset => :get,
                          :advisors_list => :get,
                          :brokers_list => :get,
                          :employees_list => :get,
                          :all => :get,
                          :search => :any,
                          :list => :any
                        },
                        :has_many => :user_attachments,
                        :member =>  { :finish_password_reset => :put, :reset_lockout => :put },
                        :new => { :broker => :get } do |user|
                          user.resources :notes
                        end

#----------------------------------------------------------------------------

  map.resource :session
  map.setup_advisor_performance '/performance/advisors/:id/setup', :controller => 'advisors', :action => "setup_performance"

  Archive::Category::ADVISOR_CATEGORIES.each_pair do |k,v|
    eval "map.advisor_#{k.gsub('-', '_')} '/performance/advisors/:id/#{k}', :controller => 'advisors', :action => 'performance', :category => '#{k}'"
  end
  map.advisor_combined '/performance/advisors/:id/combined', :controller => 'advisors', :action => 'performance', :category => 'combined'
  map.advisor_fixed '/performance/advisors/:id/fixed', :controller => 'advisors', :action => 'performance', :category => 'fixed'
  map.advisor_profile '/producers/advisors/:id/profile', :controller => 'advisors', :action => 'profile'
  map.advisor_profile_contact '/producers/advisors/:id/profile_contact', :controller => 'advisors', :action => 'profile_contact'
  map.advisor_profile_producer '/producers/advisors/:id/profile_producer', :controller => 'advisors', :action => 'profile_producer'
  map.advisor_profile_broker '/producers/advisors/:id/profile_broker', :controller => 'advisors', :action => 'profile_broker'
  map.advisor_profile_communications '/producers/advisors/:id/profile_communications', :controller => 'advisors', :action => 'profile_communications'
  map.advisor_profile_account '/producers/advisors/:id/profile_account', :controller => 'advisors', :action => 'profile_account'
  map.advisor_premium '/producers/advisors/:id/premium', :controller => 'advisors', :action => 'premium'
  map.team_summary '/performance/teams/:id/:tab', :controller => 'teams', :action => 'summary'
  map.advisor_gdc_summary '/producers/advisors/:id/gdc', :controller => 'advisors', :action => 'gdc_summary'
  map.advisor_eap '/producers/advisors/:id/eap', :controller => 'advisors', :action => 'gdc_summary'
  map.advisor_compensation '/producers/advisors/:id/compensation', :controller => 'advisors', :action => 'compensation'
  map.compensation_report '/producers/advisors/:id/reports/:report.pdf', :controller => 'advisors', :action => 'compensation_report', :format => :pdf
  map.anniversary_compensation_report '/producers/advisors/:id/reports/:report', :controller => 'advisors', :action => 'compensation_report', :format => :pdf
  map.advisor_communication '/producers/advisors/:id/communication', :controller => 'advisors', :action => 'communication'
  map.advisor_cases '/producers/advisors/:id/cases', :controller => 'advisors', :action => 'cases'
  map.advisor_documents '/producers/advisors/:id/documents', :controller => 'advisors', :action => 'documents'
  map.advisor_club_credits '/producers/advisors/:id/club_credits', :controller => 'advisors', :action => 'club_credits'
  map.forgot_password '/account/forgot', :controller => 'sessions', :action => 'forgot'
  map.broker_forgot_password '/account/broker_forgot', :controller => 'sessions', :action => 'broker_forgot'
  map.reset_password '/account/reset/:token', :controller => 'sessions', :action => 'reset'
  map.account_setup '/account/setup', :controller => 'accounts', :action => 'setup'
  map.account_stasis '/account/stasis', :controller => 'accounts', :action => 'stasis'
  # Company - TODO REMOVE
  map.with_options :controller => 'performance' do |perf|
    perf.company_performance_combined '/performance/company/combined', :action => 'combined'
    perf.company_performance_fixed '/performance/company/fixed', :action => 'fixed'
    perf.company_performance_home '/performance/company', :action => 'index'
    perf.company_setup_data '/performance/company/setup', :action => 'setup_data'
    perf.company_performance_update '/performance/company/setup-data', :action => 'update'
    perf.import_data '/performance/company/import-data', :action => 'import'
    perf.company_performance '/performance/company/:category', :action => 'performance_by_category'
  end
  map.performance '/performance/company/combined', :controller => 'performance', :action => 'combined'
  map.with_options :controller => 'gdc' do |gdc|
    gdc.gdc_report '/performance/gdc-report', :action => 'monthly'
  end
  # TODO: Get rid of manager_controller.  Move gdc to gdc controller
  map.with_options :controller => 'manager' do |mgmt|
    mgmt.gdc_payouts '/performance/gdc/payouts', :action => 'gdc_payouts'
    mgmt.gdc_payout_sandbox '/performance/gdc/payout_sandbox', :action => 'gdc_payout_sandbox'
  end
  map.with_options :controller => 'expense_allowances' do |allowance|
    allowance.expense_allowance_summary '/performance/eap/summary', :action => 'summary'
    allowance.expense_allowance_by_category '/performance/eap/by_category', :action => 'by_category'
    allowance.advisor_expense_allowances '/performance/advisors/:advisor_id/eap', :action => 'by_advisor'
  end
  map.attachment '/messages/:id/attachments/:filename.:format', :controller => 'messages', :action => 'attachments'

  map.resources :resources, :except => :show, :collection => {:resource_center => :get}
  map.resources :pre_policies, :collection => {:center => :get}

#----------------------------------------------------------------------------
# Messages
  map.resources :messages,
                :collection =>  {
                                  :sent => :get,
                                  :received => :get,
                                  :unread => :get,
                                  :create_reply => :post,
                                  :message_center => :get,
                                  :create_for_case => :post,
                                  :admin_listing => :get
                                },
                :member =>      {
                                  :reply => :get,
                                  :forward => :post,
                                  :admin_edit => :any
                                }


map.resources :weekly_messages, :except => :show

#----------------------------------------------------------------------------
# Quotes

  map.resources :quotes, :collection => { :wizard => :get,
                                          :quote_center => :get,
                                          :wizard_launch => :get,
                                          :windsor => :any,
                                          :create_windsor => :any,
                                          :windsor_thankyou => :any,
                                          :list => :any
                                        }

#----------------------------------------------------------------------------
# Contact Us Form

  map.with_options :controller => 'contact' do |contact|
    contact.contact '/contact',
      :action => 'index',
      :conditions => { :method => :get }

    contact.contact '/contact',
      :action => 'create',
      :conditions => { :method => :post }
  end

#----------------------------------------------------------------------------
# Help Pages

  map.help '/help', :controller => 'help', :action => 'index'
  map.help_topic '/help/:topic', :controller => 'help', :action => 'show'

#----------------------------------------------------------------------------
# Static Routes
  if Rails.env.development? || Rails.env.staging? # Useful for development/styling work
    map.jquery_ui '/jquery_ui', :controller => 'static', :action => 'jquery_ui'
    map.jquery_dialog '/jquery_dialog', :controller => 'static', :action => 'jquery_dialog'
    map.styling_static '/styling_static', :controller => 'static', :action => 'styling_static'
    map.modal_dialog '/modal_dialog', :controller => 'static', :action => 'modal_dialog'
    map.charting 'charting', :controller => 'static', :action => 'charting'
  end
  map.security '/security', :controller => 'static', :action => 'security'
  map.revisions '/revisions', :controller => 'static', :action => 'revisions'
  map.claim 'claim', :controller => 'static', :action => 'claim'
  map.about 'about', :controller => 'static', :action => 'about'
  map.case_status_help '/case_status_help', :controller => 'static', :action => 'case_status_help'
  map.training 'training', :controller => 'static', :action => 'training'
  map.nbu_screenshots 'nbu_screenshots', :controller => 'static', :action => 'nbu_screenshots'

end
#== Route Map
# Generated on 02 May 2010 09:20
#
#                                      root        /                                                                      {:controller=>"dashboard", :action=>"redirect"}
#                         dashboard_history        /dashboard/:y/:m                                                       {:controller=>"dashboard", :action=>"history"}
#                            dashboard_year        /dashboard/:y                                                          {:controller=>"dashboard", :action=>"full_year"}
#                                 dashboard        /dashboard                                                             {:controller=>"dashboard", :action=>"index"}
#           sale_case_sale_case_attachments GET    /cases/:sale_case_id/sale_case_attachments(.:format)                   {:controller=>"sale_case_attachments", :action=>"index"}
#                                           POST   /cases/:sale_case_id/sale_case_attachments(.:format)                   {:controller=>"sale_case_attachments", :action=>"create"}
#        new_sale_case_sale_case_attachment GET    /cases/:sale_case_id/sale_case_attachments/new(.:format)               {:controller=>"sale_case_attachments", :action=>"new"}
#       edit_sale_case_sale_case_attachment GET    /cases/:sale_case_id/sale_case_attachments/:id/edit(.:format)          {:controller=>"sale_case_attachments", :action=>"edit"}
#            sale_case_sale_case_attachment GET    /cases/:sale_case_id/sale_case_attachments/:id(.:format)               {:controller=>"sale_case_attachments", :action=>"show"}
#                                           PUT    /cases/:sale_case_id/sale_case_attachments/:id(.:format)               {:controller=>"sale_case_attachments", :action=>"update"}
#                                           DELETE /cases/:sale_case_id/sale_case_attachments/:id(.:format)               {:controller=>"sale_case_attachments", :action=>"destroy"}
#                        pending_sale_cases        /cases/pending(.:format)                                               {:controller=>"sale_cases", :action=>"pending"}
#                           list_sale_cases        /cases/list(.:format)                                                  {:controller=>"sale_cases", :action=>"list"}
#                   summary_list_sale_cases        /cases/summary_list(.:format)                                          {:controller=>"sale_cases", :action=>"summary_list"}
#                                sale_cases GET    /cases(.:format)                                                       {:controller=>"sale_cases", :action=>"index"}
#                                           POST   /cases(.:format)                                                       {:controller=>"sale_cases", :action=>"create"}
#                             new_sale_case GET    /cases/new(.:format)                                                   {:controller=>"sale_cases", :action=>"new"}
#                            edit_sale_case GET    /cases/:id/edit(.:format)                                              {:controller=>"sale_cases", :action=>"edit"}
#                                 sale_case GET    /cases/:id(.:format)                                                   {:controller=>"sale_cases", :action=>"show"}
#                                           PUT    /cases/:id(.:format)                                                   {:controller=>"sale_cases", :action=>"update"}
#                                           DELETE /cases/:id(.:format)                                                   {:controller=>"sale_cases", :action=>"destroy"}
#                           case_attachment        /sale_case_attachments/:id/attachments/:filename(.:format)             {:controller=>"sale_case_attachments", :action=>"attachments"}
#                   sale_case_relationships GET    /sale_case_relationships(.:format)                                     {:controller=>"sale_case_relationships", :action=>"index"}
#                                           POST   /sale_case_relationships(.:format)                                     {:controller=>"sale_case_relationships", :action=>"create"}
#                new_sale_case_relationship GET    /sale_case_relationships/new(.:format)                                 {:controller=>"sale_case_relationships", :action=>"new"}
#               edit_sale_case_relationship GET    /sale_case_relationships/:id/edit(.:format)                            {:controller=>"sale_case_relationships", :action=>"edit"}
#                    sale_case_relationship GET    /sale_case_relationships/:id(.:format)                                 {:controller=>"sale_case_relationships", :action=>"show"}
#                                           PUT    /sale_case_relationships/:id(.:format)                                 {:controller=>"sale_case_relationships", :action=>"update"}
#                                           DELETE /sale_case_relationships/:id(.:format)                                 {:controller=>"sale_case_relationships", :action=>"destroy"}
#                           guardian_people GET    /guardian_people(.:format)                                             {:controller=>"guardian_people", :action=>"index"}
#                                           POST   /guardian_people(.:format)                                             {:controller=>"guardian_people", :action=>"create"}
#                       new_guardian_person GET    /guardian_people/new(.:format)                                         {:controller=>"guardian_people", :action=>"new"}
#                      edit_guardian_person GET    /guardian_people/:id/edit(.:format)                                    {:controller=>"guardian_people", :action=>"edit"}
#                           guardian_person GET    /guardian_people/:id(.:format)                                         {:controller=>"guardian_people", :action=>"show"}
#                                           PUT    /guardian_people/:id(.:format)                                         {:controller=>"guardian_people", :action=>"update"}
#                                           DELETE /guardian_people/:id(.:format)                                         {:controller=>"guardian_people", :action=>"destroy"}
#                     sale_cases_all_stages        /cases/all_stages                                                      {:controller=>"sale_case", :action=>"cases_by_stage"}
#                               data_status        /admin/status                                                          {:controller=>"data", :action=>"status"}
#                               data_import        /data/import                                                           {:controller=>"data", :action=>"import"}
#                       data_import_frfsall        /data/import/frfsall                                                   {:controller=>"data", :action=>"import_frfsall"}
#                           data_import_eap        /data/import/eap                                                       {:controller=>"data", :action=>"import_eap"}
#                           data_import_gdc        /data/import/gdc                                                       {:controller=>"data", :action=>"import_gdc"}
#                           import_clubsumm        /performance/clubsumm-reports                                          {:controller=>"accounts", :action=>"import_reports"}
#                                     admin        /admin                                                                 {:controller=>"users", :action=>"index"}
#                                  register        /register                                                              {:controller=>"users", :action=>"register"}
#                             create_broker        /create_broker                                                         {:controller=>"users", :action=>"create_broker"}
#                                 signed_up        /signed_up/:code                                                       {:controller=>"users", :action=>"signed_up"}
#                                  activate        /activate/:code                                                        {:controller=>"users", :action=>"activate"}
#                                     login        /login                                                                 {:controller=>"sessions", :action=>"new"}
#                                    logout        /logout                                                                {:controller=>"sessions", :action=>"destroy"}
#                                    active        /active                                                                {:controller=>"sessions", :action=>"active"}
#                                   timeout        /timeout                                                               {:controller=>"sessions", :action=>"timeout"}
#                                login_help        /login_help                                                            {:controller=>"sessions", :action=>"help"}
#                                 audit_log        /admin/logs                                                            {:controller=>"footprints", :action=>"log"}
#                                 footprint        /admin/logs/detail/:id                                                 {:controller=>"footprints", :action=>"show"}
#                                 forecasts GET    /forecasts(.:format)                                                   {:controller=>"forecasts", :action=>"index"}
#                                           POST   /forecasts(.:format)                                                   {:controller=>"forecasts", :action=>"create"}
#                              new_forecast GET    /forecasts/new(.:format)                                               {:controller=>"forecasts", :action=>"new"}
#                             edit_forecast GET    /forecasts/:id/edit(.:format)                                          {:controller=>"forecasts", :action=>"edit"}
#                                  forecast GET    /forecasts/:id(.:format)                                               {:controller=>"forecasts", :action=>"show"}
#                                           PUT    /forecasts/:id(.:format)                                               {:controller=>"forecasts", :action=>"update"}
#                                           DELETE /forecasts/:id(.:format)                                               {:controller=>"forecasts", :action=>"destroy"}
#                           no_access_notes GET    /admin/notes/no_access(.:format)                                       {:controller=>"notes", :action=>"no_access"}
#                                     notes GET    /admin/notes(.:format)                                                 {:controller=>"notes", :action=>"index"}
#                                           POST   /admin/notes(.:format)                                                 {:controller=>"notes", :action=>"create"}
#                                  new_note GET    /admin/notes/new(.:format)                                             {:controller=>"notes", :action=>"new"}
#                         access_level_note POST   /admin/notes/:id/access_level(.:format)                                {:controller=>"notes", :action=>"access_level"}
#                                 edit_note GET    /admin/notes/:id/edit(.:format)                                        {:controller=>"notes", :action=>"edit"}
#                                      note GET    /admin/notes/:id(.:format)                                             {:controller=>"notes", :action=>"show"}
#                                           PUT    /admin/notes/:id(.:format)                                             {:controller=>"notes", :action=>"update"}
#                                           DELETE /admin/notes/:id(.:format)                                             {:controller=>"notes", :action=>"destroy"}
#                        policy_event_notes GET    /policies/policy_events/:policy_event_id/notes(.:format)               {:controller=>"notes", :action=>"index"}
#                                           POST   /policies/policy_events/:policy_event_id/notes(.:format)               {:controller=>"notes", :action=>"create"}
#                     new_policy_event_note GET    /policies/policy_events/:policy_event_id/notes/new(.:format)           {:controller=>"notes", :action=>"new"}
#                    edit_policy_event_note GET    /policies/policy_events/:policy_event_id/notes/:id/edit(.:format)      {:controller=>"notes", :action=>"edit"}
#                         policy_event_note GET    /policies/policy_events/:policy_event_id/notes/:id(.:format)           {:controller=>"notes", :action=>"show"}
#                                           PUT    /policies/policy_events/:policy_event_id/notes/:id(.:format)           {:controller=>"notes", :action=>"update"}
#                                           DELETE /policies/policy_events/:policy_event_id/notes/:id(.:format)           {:controller=>"notes", :action=>"destroy"}
#                             policy_events GET    /policies/policy_events(.:format)                                      {:controller=>"policy_events", :action=>"index"}
#                                           POST   /policies/policy_events(.:format)                                      {:controller=>"policy_events", :action=>"create"}
#                          new_policy_event GET    /policies/policy_events/new(.:format)                                  {:controller=>"policy_events", :action=>"new"}
#                         edit_policy_event GET    /policies/policy_events/:id/edit(.:format)                             {:controller=>"policy_events", :action=>"edit"}
#                              policy_event GET    /policies/policy_events/:id(.:format)                                  {:controller=>"policy_events", :action=>"show"}
#                                           PUT    /policies/policy_events/:id(.:format)                                  {:controller=>"policy_events", :action=>"update"}
#                                           DELETE /policies/policy_events/:id(.:format)                                  {:controller=>"policy_events", :action=>"destroy"}
#                                  premiums        /performance/premiums                                                  {:controller=>"premiums", :action=>"summary"}
#                          premiums_listing        /performance/premiums/:action                                          {:controller=>"premiums"}
#                          advisor_policies        /policies/by-advisor/:advisor_id                                       {:controller=>"policies", :action=>"index"}
#                advisor_policies_by_status        /policies/by-advisor/:advisor_id/:status                               {:controller=>"policies", :action=>"index"}
#                              new_business        /policies                                                              {:controller=>"policies", :action=>"index"}
#                        policies_by_status        /policies/status/:status                                               {:controller=>"policies", :action=>"index"}
#                   policy_forecast_history        /policy/:id/history                                                    {:controller=>"policy", :action=>"history"}
#                          policy_forecasts GET    /policies/:policy_id/forecasts(.:format)                               {:controller=>"forecasts", :action=>"index"}
#                                           POST   /policies/:policy_id/forecasts(.:format)                               {:controller=>"forecasts", :action=>"create"}
#                       new_policy_forecast GET    /policies/:policy_id/forecasts/new(.:format)                           {:controller=>"forecasts", :action=>"new"}
#                      edit_policy_forecast GET    /policies/:policy_id/forecasts/:id/edit(.:format)                      {:controller=>"forecasts", :action=>"edit"}
#                           policy_forecast GET    /policies/:policy_id/forecasts/:id(.:format)                           {:controller=>"forecasts", :action=>"show"}
#                                           PUT    /policies/:policy_id/forecasts/:id(.:format)                           {:controller=>"forecasts", :action=>"update"}
#                                           DELETE /policies/:policy_id/forecasts/:id(.:format)                           {:controller=>"forecasts", :action=>"destroy"}
#                    no_access_policy_notes GET    /policies/:policy_id/notes/no_access(.:format)                         {:controller=>"notes", :action=>"no_access"}
#                              policy_notes GET    /policies/:policy_id/notes(.:format)                                   {:controller=>"notes", :action=>"index"}
#                                           POST   /policies/:policy_id/notes(.:format)                                   {:controller=>"notes", :action=>"create"}
#                           new_policy_note GET    /policies/:policy_id/notes/new(.:format)                               {:controller=>"notes", :action=>"new"}
#                                           GET    /notes/:id/edit(.:format)                                              {:controller=>"notes", :action=>"edit"}
#                                           GET    /notes/:id(.:format)                                                   {:controller=>"notes", :action=>"show"}
#                                           PUT    /notes/:id(.:format)                                                   {:controller=>"notes", :action=>"update"}
#                                           DELETE /notes/:id(.:format)                                                   {:controller=>"notes", :action=>"destroy"}
#                      policy_policy_events GET    /policies/:policy_id/policy_events(.:format)                           {:controller=>"policy_events", :action=>"index"}
#                                           POST   /policies/:policy_id/policy_events(.:format)                           {:controller=>"policy_events", :action=>"create"}
#                   new_policy_policy_event GET    /policies/:policy_id/policy_events/new(.:format)                       {:controller=>"policy_events", :action=>"new"}
#                                           GET    /policy_events/:id/edit(.:format)                                      {:controller=>"policy_events", :action=>"edit"}
#                                           GET    /policy_events/:id(.:format)                                           {:controller=>"policy_events", :action=>"show"}
#                                           PUT    /policy_events/:id(.:format)                                           {:controller=>"policy_events", :action=>"update"}
#                                           DELETE /policy_events/:id(.:format)                                           {:controller=>"policy_events", :action=>"destroy"}
#                       policy_requirements GET    /policies/:policy_id/requirements(.:format)                            {:controller=>"requirements", :action=>"index"}
#                                           POST   /policies/:policy_id/requirements(.:format)                            {:controller=>"requirements", :action=>"create"}
#                    new_policy_requirement GET    /policies/:policy_id/requirements/new(.:format)                        {:controller=>"requirements", :action=>"new"}
#                   edit_policy_requirement GET    /policies/:policy_id/requirements/:id/edit(.:format)                   {:controller=>"requirements", :action=>"edit"}
#                        policy_requirement PUT    /policies/:policy_id/requirements/:id(.:format)                        {:controller=>"requirements", :action=>"update"}
#                                           DELETE /policies/:policy_id/requirements/:id(.:format)                        {:controller=>"requirements", :action=>"destroy"}
#                           search_policies GET    /policies/search(.:format)                                             {:controller=>"policies", :action=>"search"}
#                                  policies GET    /policies(.:format)                                                    {:controller=>"policies", :action=>"index"}
#                                           POST   /policies(.:format)                                                    {:controller=>"policies", :action=>"create"}
#                                new_policy GET    /policies/new(.:format)                                                {:controller=>"policies", :action=>"new"}
#                               edit_policy GET    /policies/:id/edit(.:format)                                           {:controller=>"policies", :action=>"edit"}
#                            history_policy GET    /policies/:id/history(.:format)                                        {:controller=>"policies", :action=>"history"}
#                                    policy GET    /policies/:id(.:format)                                                {:controller=>"policies", :action=>"show"}
#                                           PUT    /policies/:id(.:format)                                                {:controller=>"policies", :action=>"update"}
#                                           DELETE /policies/:id(.:format)                                                {:controller=>"policies", :action=>"destroy"}
#                     for_user_requirements GET    /requirements/for_user(.:format)                                       {:controller=>"requirements", :action=>"for_user"}
#                                user_notes GET    /users/:user_id/notes(.:format)                                        {:controller=>"notes", :action=>"index"}
#                                           POST   /users/:user_id/notes(.:format)                                        {:controller=>"notes", :action=>"create"}
#                             new_user_note GET    /users/:user_id/notes/new(.:format)                                    {:controller=>"notes", :action=>"new"}
#                            edit_user_note GET    /users/:user_id/notes/:id/edit(.:format)                               {:controller=>"notes", :action=>"edit"}
#                                 user_note GET    /users/:user_id/notes/:id(.:format)                                    {:controller=>"notes", :action=>"show"}
#                                           PUT    /users/:user_id/notes/:id(.:format)                                    {:controller=>"notes", :action=>"update"}
#                                           DELETE /users/:user_id/notes/:id(.:format)                                    {:controller=>"notes", :action=>"destroy"}
#                   nbu_create_broker_users POST   /users/nbu_create_broker(.:format)                                     {:controller=>"users", :action=>"nbu_create_broker"}
#                      password_reset_users GET    /users/password_reset(.:format)                                        {:controller=>"users", :action=>"password_reset"}
#                                     users GET    /users(.:format)                                                       {:controller=>"users", :action=>"index"}
#                                           POST   /users(.:format)                                                       {:controller=>"users", :action=>"create"}
#                                  new_user GET    /users/new(.:format)                                                   {:controller=>"users", :action=>"new"}
#                           broker_new_user GET    /users/new/broker(.:format)                                            {:controller=>"users", :action=>"broker"}
#                                 edit_user GET    /users/:id/edit(.:format)                                              {:controller=>"users", :action=>"edit"}
#                finish_password_reset_user PUT    /users/:id/finish_password_reset(.:format)                             {:controller=>"users", :action=>"finish_password_reset"}
#                                      user GET    /users/:id(.:format)                                                   {:controller=>"users", :action=>"show"}
#                                           PUT    /users/:id(.:format)                                                   {:controller=>"users", :action=>"update"}
#                                           DELETE /users/:id(.:format)                                                   {:controller=>"users", :action=>"destroy"}
#               agency_advisor_premium_list        /performance/agency/advisor-premium-list                               {:controller=>"agency", :action=>"advisor_premium_list"}
#           agency_advisor_premium_list_bkr        /performance/agency/advisor-premium-list-bkr                           {:controller=>"agency", :action=>"advisor_premium_list_bkr"}
#            agency_advisor_premium_list_fp        /performance/agency/advisor-premium-list-fp                            {:controller=>"agency", :action=>"advisor_premium_list_fp"}
#            agency_advisor_premium_list_fr        /performance/agency/advisor-premium-list-fr                            {:controller=>"agency", :action=>"advisor_premium_list_fr"}
#       agency_advisor_premium_list_frfpfta        /performance/agency/advisor-premium-list-frfpfta                       {:controller=>"agency", :action=>"advisor_premium_list_frfpfta"}
#      agency_advisor_premium_list_bkrfpfta        /performance/agency/advisor-premium-list-bkrfpfta                      {:controller=>"agency", :action=>"advisor_premium_list_bkrfpfta"}
#          agency_advisor_premium_list_frsa        /performance/agency/advisor-premium-list-frsa                          {:controller=>"agency", :action=>"advisor_premium_list_frsa"}
#           agency_advisor_premium_list_fta        /performance/agency/advisor-premium-list-fta                           {:controller=>"agency", :action=>"advisor_premium_list_fta"}
#           agency_advisor_premium_list_mgr        /performance/agency/advisor-premium-list-mgr                           {:controller=>"agency", :action=>"advisor_premium_list_mgr"}
#           agency_advisor_premium_list_fmr        /performance/agency/advisor-premium-list-fmr                           {:controller=>"agency", :action=>"advisor_premium_list_fmr"}
# agency_advisor_premium_list_not_on_target        /performance/agency/advisor-premium-list-not-on-target                 {:controller=>"agency", :action=>"advisor_premium_list_not_on_target"}
#     agency_advisor_premium_list_on_target        /performance/agency/advisor-premium-list-on-target                     {:controller=>"agency", :action=>"advisor_premium_list_on_target"}
#     agency_advisor_premium_list_qualified        /performance/agency/advisor-premium-list-qualified                     {:controller=>"agency", :action=>"advisor_premium_list_qualified"}
#            agency_advisor_premium_list_sa        /performance/agency/advisor-premium-list-sa                            {:controller=>"agency", :action=>"advisor_premium_list_sa"}
#           agency_advisor_premium_list_all        /performance/agency/advisor-premium-list-all                           {:controller=>"agency", :action=>"advisor_premium_list_all"}
#                         club_credits_list        /:controller/club-credits-list                                         {:action=>"club_credits_list"}
#                                    agency        /performance/agency                                                    {:controller=>"agency", :action=>"show"}
#                          formatted_agency        /performance/agency(.:format)                                          {:controller=>"agency", :action=>"show"}
#                  setup_agency_performance        /performance/agency/setup                                              {:controller=>"agency", :action=>"setup_targets"}
#                            agency_summary        /performance/agency/:tab                                               {:controller=>"agency", :action=>"summary"}
#                                list_teams        /performance/teams/list(.:format)                                      {:controller=>"teams", :action=>"list"}
#                              report_teams GET    /performance/teams/report(.:format)                                    {:controller=>"teams", :action=>"report"}
#                                     teams GET    /performance/teams(.:format)                                           {:controller=>"teams", :action=>"index"}
#                                           POST   /performance/teams(.:format)                                           {:controller=>"teams", :action=>"create"}
#                                  new_team GET    /performance/teams/new(.:format)                                       {:controller=>"teams", :action=>"new"}
#                                 edit_team GET    /performance/teams/:id/edit(.:format)                                  {:controller=>"teams", :action=>"edit"}
#                        add_member_to_team GET    /performance/teams/:id/add_member_to(.:format)                         {:controller=>"teams", :action=>"add_member_to"}
#                                           POST   /performance/teams/:id/add_member_to(.:format)                         {:controller=>"teams", :action=>"add_member_to"}
#                   remove_member_from_team GET    /performance/teams/:id/remove_member_from(.:format)                    {:controller=>"teams", :action=>"remove_member_from"}
#                                           POST   /performance/teams/:id/remove_member_from(.:format)                    {:controller=>"teams", :action=>"remove_member_from"}
#                                      team GET    /performance/teams/:id(.:format)                                       {:controller=>"teams", :action=>"show"}
#                                           PUT    /performance/teams/:id(.:format)                                       {:controller=>"teams", :action=>"update"}
#                                           DELETE /performance/teams/:id(.:format)                                       {:controller=>"teams", :action=>"destroy"}
#                         team_new_business        /performance/teams/:team_id/policies                                   {:controller=>"policies", :action=>"index"}
#                                                  /performance/teams/:id/:tab                                            {:controller=>"teams", :action=>"summary"}
#                            advisor_search        /advisors/search                                                       {:controller=>"advisors", :action=>"search"}
#                      advisors_performance        /performance/advisors                                                  {:controller=>"advisors", :action=>"listing"}
#                           clubsumm_report        /performance/advisors/clubsumm                                         {:controller=>"club_reports", :action=>"index"}
#                       advisor_performance        /performance/advisors/:id                                              {:controller=>"advisors", :action=>"performance"}
#                       advisor_summary_tab        /producers/advisors/:id/summary/:tab                                   {:controller=>"advisors", :action=>"show"}
#                                  advisors GET    /producers/advisors(.:format)                                          {:controller=>"advisors", :action=>"index"}
#                                           POST   /producers/advisors(.:format)                                          {:controller=>"advisors", :action=>"create"}
#                               new_advisor GET    /producers/advisors/new(.:format)                                      {:controller=>"advisors", :action=>"new"}
#                              edit_advisor GET    /producers/advisors/:id/edit(.:format)                                 {:controller=>"advisors", :action=>"edit"}
#                                   advisor GET    /producers/advisors/:id(.:format)                                      {:controller=>"advisors", :action=>"show"}
#                                           PUT    /producers/advisors/:id(.:format)                                      {:controller=>"advisors", :action=>"update"}
#                                           DELETE /producers/advisors/:id(.:format)                                      {:controller=>"advisors", :action=>"destroy"}
#                      advisor_new_business        /performance/advisors/:advisor_id/policies                             {:controller=>"policies", :action=>"index"}
#                           advisor_reports        /performance/advisors/:advisor_id/reports                              {:controller=>"reports", :action=>"index"}
#                            advisor_report        /performance/advisors/:advisor_id/reports/:id                          {:controller=>"reports", :action=>"show"}
#                        club_qualification        /performance/club_qualification                                        {:controller=>"club_reports", :action=>"club_qualification"}
#                               advisor_gdc        /performance/advisors/:advisor_id/gdc                                  {:controller=>"gdc", :action=>"advisor"}
#                                 producers GET    /producers(.:format)                                                   {:controller=>"advisors", :action=>"index"}
#                                           POST   /producers(.:format)                                                   {:controller=>"advisors", :action=>"create"}
#                              new_producer GET    /producers/new(.:format)                                               {:controller=>"advisors", :action=>"new"}
#                             edit_producer GET    /producers/:id/edit(.:format)                                          {:controller=>"advisors", :action=>"edit"}
#                                  producer GET    /producers/:id(.:format)                                               {:controller=>"advisors", :action=>"show"}
#                                           PUT    /producers/:id(.:format)                                               {:controller=>"advisors", :action=>"update"}
#                                           DELETE /producers/:id(.:format)                                               {:controller=>"advisors", :action=>"destroy"}
#                            clubsumm_chart        /charts/clubsumm.xml                                                   {:controller=>"charts", :format=>"xml", :action=>"clubsumm"}
#                    clubsumm_details_chart        /charts/clubsumm-details.xml                                           {:controller=>"charts", :format=>"xml", :action=>"clubsumm_details"}
#                     agency_premiums_chart        /charts/agency/premiums(.:format)                                      {:controller=>"charts", :action=>"premiums"}
#                    advisor_premiums_chart        /charts/advisor/:advisor_id/premiums(.:format)                         {:controller=>"charts", :action=>"premiums"}
#                       team_premiums_chart        /charts/team/:team_id/premiums(.:format)                               {:controller=>"charts", :action=>"premiums"}
#              advisor_premiums_month_chart        /charts/advisor/:advisor_id/premiums-for-month(.:format)               {:controller=>"charts", :action=>"premiums_for_month"}
#                 team_premiums_month_chart        /charts/team/:team_id/premiums-for-month(.:format)                     {:controller=>"charts", :action=>"premiums_for_month"}
#               agency_premiums_month_chart        /charts/agency/premiums-for-month(.:format)                            {:controller=>"charts", :action=>"premiums_for_month"}
#      advisor_premiums_quarter_by_category        /charts/advisor/:advisor_id/premiums-by-category-for-quarter(.:format) {:controller=>"charts", :action=>"premiums_by_category_for_quarter"}
#         team_premiums_quarter_by_category        /charts/team/:team_id/premiums-by-category-for-quarter(.:format)       {:controller=>"charts", :action=>"premiums_by_category_for_quarter"}
#       agency_premiums_quarter_by_category        /charts/agency/premiums-by-category-for-quarter(.:format)              {:controller=>"charts", :action=>"premiums_by_category_for_quarter"}
#        advisor_premiums_month_by_category        /charts/advisor/:advisor_id/premiums-by-category-for-month(.:format)   {:controller=>"charts", :action=>"premiums_by_category_for_month"}
#           team_premiums_month_by_category        /charts/team/:team_id/premiums-by-category-for-month(.:format)         {:controller=>"charts", :action=>"premiums_by_category_for_month"}
#         agency_premiums_month_by_category        /charts/agency/premiums-by-category-for-month(.:format)                {:controller=>"charts", :action=>"premiums_by_category_for_month"}
#                 agency_club_runrate_chart        /charts/company/:category(.:format)                                    {:controller=>"charts", :action=>"agency_club_runrate"}
#                    advisor_clubsumm_chart        /charts/advisor/:id/clubsumm(.:format)                                 {:controller=>"charts", :action=>"advisor_clubsumm"}
#              advisor_premiums_by_category        /charts/advisor/:advisor_id/premiums-by-category(.:format)             {:controller=>"charts", :action=>"premiums_by_category"}
#               agency_clubsumm_by_category        /charts/agency/clubsumm-by-category(.:format)                          {:controller=>"charts", :action=>"agency_clubsumm_by_category"}
#               agency_premiums_by_category        /charts/agency/premiums-by-category(.:format)                          {:controller=>"charts", :action=>"premiums_by_category"}
#                 team_premiums_by_category        /charts/team/:team_id/premiums-by-category(.:format)                   {:controller=>"charts", :action=>"premiums_by_category"}
#                             advisor_chart        /charts/advisor/:id/:category(.:format)                                {:controller=>"charts", :action=>"advisor_run_rate"}
#                       team_clubsumm_chart        /charts/team/:id/clubsumm-by-category(.:format)                        {:controller=>"charts", :action=>"team_clubsumm_by_category"}
#                        unit_runrate_chart        /charts/team/:id/:category(.:format)                                   {:controller=>"charts", :action=>"unit_run_rate"}
#                      top_performers_chart        /charts/top-performers(.:format)                                       {:controller=>"charts", :action=>"top_performers"}
#                            cancel_account        /account/cancel(.:format)                                              {:controller=>"accounts", :action=>"cancel"}
#                              plan_account        /account/plan(.:format)                                                {:controller=>"accounts", :action=>"plan"}
#                           billing_account        /account/billing(.:format)                                             {:controller=>"accounts", :action=>"billing"}
#                            thanks_account GET    /account/thanks(.:format)                                              {:controller=>"accounts", :action=>"thanks"}
#                          canceled_account GET    /account/canceled(.:format)                                            {:controller=>"accounts", :action=>"canceled"}
#                         dashboard_account GET    /account/dashboard(.:format)                                           {:controller=>"accounts", :action=>"dashboard"}
#                             plans_account GET    /account/plans(.:format)                                               {:controller=>"accounts", :action=>"plans"}
#                               new_account GET    /account/new(.:format)                                                 {:controller=>"accounts", :action=>"new"}
#                              edit_account GET    /account/edit(.:format)                                                {:controller=>"accounts", :action=>"edit"}
#                                   account GET    /account(.:format)                                                     {:controller=>"accounts", :action=>"show"}
#                                           PUT    /account(.:format)                                                     {:controller=>"accounts", :action=>"update"}
#                                           DELETE /account(.:format)                                                     {:controller=>"accounts", :action=>"destroy"}
#                                           POST   /account(.:format)                                                     {:controller=>"accounts", :action=>"create"}
#                               new_session GET    /session/new(.:format)                                                 {:controller=>"sessions", :action=>"new"}
#                              edit_session GET    /session/edit(.:format)                                                {:controller=>"sessions", :action=>"edit"}
#                                   session GET    /session(.:format)                                                     {:controller=>"sessions", :action=>"show"}
#                                           PUT    /session(.:format)                                                     {:controller=>"sessions", :action=>"update"}
#                                           DELETE /session(.:format)                                                     {:controller=>"sessions", :action=>"destroy"}
#                                           POST   /session(.:format)                                                     {:controller=>"sessions", :action=>"create"}
#                 setup_advisor_performance        /performance/advisors/:id/setup                                        {:controller=>"advisors", :action=>"setup_performance"}
#                       advisors_list_users GET    /admin/users/advisors_list(.:format)                                   {:controller=>"users", :action=>"advisors_list"}
#                                 all_users GET    /admin/users/all(.:format)                                             {:controller=>"users", :action=>"all"}
#                        brokers_list_users GET    /admin/users/brokers_list(.:format)                                    {:controller=>"users", :action=>"brokers_list"}
#                      employees_list_users GET    /admin/users/employees_list(.:format)                                  {:controller=>"users", :action=>"employees_list"}
#                                           GET    /admin/users(.:format)                                                 {:controller=>"users", :action=>"index"}
#                                           POST   /admin/users(.:format)                                                 {:controller=>"users", :action=>"create"}
#                                           GET    /admin/users/new(.:format)                                             {:controller=>"users", :action=>"new"}
#                                           GET    /admin/users/:id/edit(.:format)                                        {:controller=>"users", :action=>"edit"}
#                                           GET    /admin/users/:id(.:format)                                             {:controller=>"users", :action=>"show"}
#                                           PUT    /admin/users/:id(.:format)                                             {:controller=>"users", :action=>"update"}
#                                           DELETE /admin/users/:id(.:format)                                             {:controller=>"users", :action=>"destroy"}
#                            advisor_gdc_np        /performance/advisors/:id/gdc-np                                       {:category=>"gdc-np", :controller=>"advisors", :action=>"performance"}
#                             advisor_gdc_p        /performance/advisors/:id/gdc-p                                        {:category=>"gdc-p", :controller=>"advisors", :action=>"performance"}
#                               advisor_ltc        /performance/advisors/:id/ltc                                          {:category=>"ltc", :controller=>"advisors", :action=>"performance"}
#                advisor_club_credits_other        /performance/advisors/:id/club-credits-other                           {:category=>"club-credits-other", :controller=>"advisors", :action=>"performance"}
#                        advisor_disability        /performance/advisors/:id/disability                                   {:category=>"disability", :controller=>"advisors", :action=>"performance"}
#                              advisor_life        /performance/advisors/:id/life                                         {:category=>"life", :controller=>"advisors", :action=>"performance"}
#                          advisor_combined        /performance/advisors/:id/combined                                     {:category=>"combined", :controller=>"advisors", :action=>"performance"}
#                             advisor_fixed        /performance/advisors/:id/fixed                                        {:category=>"fixed", :controller=>"advisors", :action=>"performance"}
#                           advisor_profile        /producers/advisors/:id/profile                                        {:controller=>"advisors", :action=>"profile"}
#                   advisor_profile_contact        /producers/advisors/:id/profile_contact                                {:controller=>"advisors", :action=>"profile_contact"}
#                  advisor_profile_producer        /producers/advisors/:id/profile_producer                               {:controller=>"advisors", :action=>"profile_producer"}
#                    advisor_profile_broker        /producers/advisors/:id/profile_broker                                 {:controller=>"advisors", :action=>"profile_broker"}
#            advisor_profile_communications        /producers/advisors/:id/profile_communications                         {:controller=>"advisors", :action=>"profile_communications"}
#                   advisor_profile_account        /producers/advisors/:id/profile_account                                {:controller=>"advisors", :action=>"profile_account"}
#                           advisor_premium        /producers/advisors/:id/premium                                        {:controller=>"advisors", :action=>"premium"}
#                              team_summary        /performance/teams/:id/:tab                                            {:controller=>"teams", :action=>"summary"}
#                       advisor_gdc_summary        /producers/advisors/:id/gdc                                            {:controller=>"advisors", :action=>"gdc_summary"}
#                               advisor_eap        /producers/advisors/:id/eap                                            {:controller=>"advisors", :action=>"gdc_summary"}
#                      advisor_compensation        /producers/advisors/:id/compensation                                   {:controller=>"advisors", :action=>"compensation"}
#                       compensation_report        /producers/advisors/:id/reports/:report.pdf                            {:controller=>"advisors", :format=>:pdf, :action=>"compensation_report"}
#           anniversary_compensation_report        /producers/advisors/:id/reports/:report                                {:controller=>"advisors", :format=>:pdf, :action=>"compensation_report"}
#                     advisor_communication        /producers/advisors/:id/communication                                  {:controller=>"advisors", :action=>"communication"}
#                      advisor_club_credits        /producers/advisors/:id/club_credits                                   {:controller=>"advisors", :action=>"club_credits"}
#                           forgot_password        /account/forgot                                                        {:controller=>"sessions", :action=>"forgot"}
#                    broker_forgot_password        /account/broker_forgot                                                 {:controller=>"sessions", :action=>"broker_forgot"}
#                            reset_password        /account/reset/:token                                                  {:controller=>"sessions", :action=>"reset"}
#                             account_setup        /account/setup                                                         {:controller=>"accounts", :action=>"setup"}
#                            account_stasis        /account/stasis                                                        {:controller=>"accounts", :action=>"stasis"}
#              company_performance_combined        /performance/company/combined                                          {:controller=>"performance", :action=>"combined"}
#                 company_performance_fixed        /performance/company/fixed                                             {:controller=>"performance", :action=>"fixed"}
#                  company_performance_home        /performance/company                                                   {:controller=>"performance", :action=>"index"}
#                        company_setup_data        /performance/company/setup                                             {:controller=>"performance", :action=>"setup_data"}
#                company_performance_update        /performance/company/setup-data                                        {:controller=>"performance", :action=>"update"}
#                               import_data        /performance/company/import-data                                       {:controller=>"performance", :action=>"import"}
#                       company_performance        /performance/company/:category                                         {:controller=>"performance", :action=>"performance_by_category"}
#                               performance        /performance/company/combined                                          {:controller=>"performance", :action=>"combined"}
#                                gdc_report        /performance/gdc-report                                                {:controller=>"gdc", :action=>"monthly"}
#                               gdc_payouts        /performance/gdc/payouts                                               {:controller=>"manager", :action=>"gdc_payouts"}
#                        gdc_payout_sandbox        /performance/gdc/payout_sandbox                                        {:controller=>"manager", :action=>"gdc_payout_sandbox"}
#                 expense_allowance_summary        /performance/eap/summary                                               {:controller=>"expense_allowances", :action=>"summary"}
#             expense_allowance_by_category        /performance/eap/by_category                                           {:controller=>"expense_allowances", :action=>"by_category"}
#                advisor_expense_allowances        /performance/advisors/:advisor_id/eap                                  {:controller=>"expense_allowances", :action=>"by_advisor"}
#                                attachment        /messages/:id/attachments/:filename(.:format)                          {:controller=>"messages", :action=>"attachments"}
#                 resource_center_resources GET    /resources/resource_center(.:format)                                   {:controller=>"resources", :action=>"resource_center"}
#                                 resources GET    /resources(.:format)                                                   {:controller=>"resources", :action=>"index"}
#                                           POST   /resources(.:format)                                                   {:controller=>"resources", :action=>"create"}
#                              new_resource GET    /resources/new(.:format)                                               {:controller=>"resources", :action=>"new"}
#                             edit_resource GET    /resources/:id/edit(.:format)                                          {:controller=>"resources", :action=>"edit"}
#                                  resource PUT    /resources/:id(.:format)                                               {:controller=>"resources", :action=>"update"}
#                                           DELETE /resources/:id(.:format)                                               {:controller=>"resources", :action=>"destroy"}
#                       center_pre_policies GET    /pre_policies/center(.:format)                                         {:controller=>"pre_policies", :action=>"center"}
#                              pre_policies GET    /pre_policies(.:format)                                                {:controller=>"pre_policies", :action=>"index"}
#                                           POST   /pre_policies(.:format)                                                {:controller=>"pre_policies", :action=>"create"}
#                            new_pre_policy GET    /pre_policies/new(.:format)                                            {:controller=>"pre_policies", :action=>"new"}
#                           edit_pre_policy GET    /pre_policies/:id/edit(.:format)                                       {:controller=>"pre_policies", :action=>"edit"}
#                                pre_policy GET    /pre_policies/:id(.:format)                                            {:controller=>"pre_policies", :action=>"show"}
#                                           PUT    /pre_policies/:id(.:format)                                            {:controller=>"pre_policies", :action=>"update"}
#                                           DELETE /pre_policies/:id(.:format)                                            {:controller=>"pre_policies", :action=>"destroy"}
#                     create_reply_messages POST   /messages/create_reply(.:format)                                       {:controller=>"messages", :action=>"create_reply"}
#                         received_messages GET    /messages/received(.:format)                                           {:controller=>"messages", :action=>"received"}
#                   message_center_messages GET    /messages/message_center(.:format)                                     {:controller=>"messages", :action=>"message_center"}
#                             sent_messages GET    /messages/sent(.:format)                                               {:controller=>"messages", :action=>"sent"}
#                                  messages GET    /messages(.:format)                                                    {:controller=>"messages", :action=>"index"}
#                                           POST   /messages(.:format)                                                    {:controller=>"messages", :action=>"create"}
#                               new_message GET    /messages/new(.:format)                                                {:controller=>"messages", :action=>"new"}
#                           forward_message POST   /messages/:id/forward(.:format)                                        {:controller=>"messages", :action=>"forward"}
#                              edit_message GET    /messages/:id/edit(.:format)                                           {:controller=>"messages", :action=>"edit"}
#                             reply_message GET    /messages/:id/reply(.:format)                                          {:controller=>"messages", :action=>"reply"}
#                                   message GET    /messages/:id(.:format)                                                {:controller=>"messages", :action=>"show"}
#                                           PUT    /messages/:id(.:format)                                                {:controller=>"messages", :action=>"update"}
#                                           DELETE /messages/:id(.:format)                                                {:controller=>"messages", :action=>"destroy"}
#                       quote_center_quotes GET    /quotes/quote_center(.:format)                                         {:controller=>"quotes", :action=>"quote_center"}
#                      wizard_launch_quotes GET    /quotes/wizard_launch(.:format)                                        {:controller=>"quotes", :action=>"wizard_launch"}
#                             wizard_quotes GET    /quotes/wizard(.:format)                                               {:controller=>"quotes", :action=>"wizard"}
#                                    quotes GET    /quotes(.:format)                                                      {:controller=>"quotes", :action=>"index"}
#                                           POST   /quotes(.:format)                                                      {:controller=>"quotes", :action=>"create"}
#                                 new_quote GET    /quotes/new(.:format)                                                  {:controller=>"quotes", :action=>"new"}
#                                edit_quote GET    /quotes/:id/edit(.:format)                                             {:controller=>"quotes", :action=>"edit"}
#                                     quote GET    /quotes/:id(.:format)                                                  {:controller=>"quotes", :action=>"show"}
#                                           PUT    /quotes/:id(.:format)                                                  {:controller=>"quotes", :action=>"update"}
#                                           DELETE /quotes/:id(.:format)                                                  {:controller=>"quotes", :action=>"destroy"}
#                           weekly_messages GET    /weekly_messages(.:format)                                             {:controller=>"weekly_messages", :action=>"index"}
#                                           POST   /weekly_messages(.:format)                                             {:controller=>"weekly_messages", :action=>"create"}
#                        new_weekly_message GET    /weekly_messages/new(.:format)                                         {:controller=>"weekly_messages", :action=>"new"}
#                       edit_weekly_message GET    /weekly_messages/:id/edit(.:format)                                    {:controller=>"weekly_messages", :action=>"edit"}
#                            weekly_message PUT    /weekly_messages/:id(.:format)                                         {:controller=>"weekly_messages", :action=>"update"}
#                                           DELETE /weekly_messages/:id(.:format)                                         {:controller=>"weekly_messages", :action=>"destroy"}
#                                 jquery_ui        /jquery_ui                                                             {:controller=>"static", :action=>"jquery_ui"}
#                            styling_static        /styling_static                                                        {:controller=>"static", :action=>"styling_static"}
#                                  security        /security                                                              {:controller=>"static", :action=>"security"}
#                                 revisions        /revisions                                                             {:controller=>"static", :action=>"revisions"}
#                                     claim        /claim                                                                 {:controller=>"static", :action=>"claim"}
#                                     about        /about                                                                 {:controller=>"static", :action=>"about"}
#                                contact_us        /contact_us                                                            {:controller=>"static", :action=>"contact_us"}
#                                       nbu        /nbu                                                                   {:controller=>"dashboard", :action=>"nbu"}
# Loaded suite /Users/mike/.rvm/ruby-1.8.7-p248/bin/rake
# Started
#
#
# Finished in 7.2e-05 seconds.
#
# 0 tests, 0 assertions, 0 failures, 0 errors, 0 pendings, 0 omissions, 0 notifications
# 0% passed
