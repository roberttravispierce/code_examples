# See "doc/LICENSE" for the license governing this code.

# Temp. key to help me translate self-referential tutorials to our situation:
#
# friendship = sale_case_relationship
# friendships = sale_case_relationships
#
# friend = related_sale_case
# friends = related_sale_cases
#
# user = sale_case

# Status Codes:
# ALL   All
# UNS   Unsubmitted
# SUBM  Submitted
# CAPP  Conditionally Approved
# UAPP  UW Approved
# APPD  Approved
# I/NP  Issued/Not Paid
# PAID  Paid
# NTKN  Not Taken
# DECL  Declined
# INC   Incomplete
# REPL  Replaced
# BKPD  Berkshire Paid

# How a Policy type is determined:
# LTC Policy Numbers begin w/ the letter "K"
# DI Policy Numbers begin w/ the letters "Z" or "G"
# All others all rolled up under Life

class SaleCase < ActiveRecord::Base
  has_paper_trail

  has_many  :sale_case_relationships
  has_many  :sale_case_attachments
  has_many  :sale_case_shares, :dependent => :destroy
  accepts_nested_attributes_for :sale_case_shares, :allow_destroy => true, :reject_if => :reject_nested_sale_case_share
  has_many :producers, :through => :sale_case_shares
  has_many :transitions, :class_name => 'SaleCaseTransition', :dependent => :destroy

  has_many  :related_sale_cases, :through => :sale_case_relationships, :after_add => :reciprocate_relationship, :after_remove => :remove_relationship
  belongs_to :glic_underwriter, :class_name => "GuardianPerson"
  belongs_to :glic_coordinator, :class_name => "GuardianPerson"
  belongs_to :glic_supervisor,  :class_name => "GuardianPerson"
  belongs_to :nbu_coordinator, :class_name => 'User'
  belongs_to :nbu_processor, :class_name => 'User'
  belongs_to :callctr_processor, :class_name => 'User'
  belongs_to :responsible_staff, :class_name => 'User'

  has_many :premiums
  has_one  :policy
  has_many :policy_events, :order => 'policy_events.status_date DESC, policy_events.ordered DESC'
  has_many :policy_shares, :include => :advisor
  has_many :advisors, :through => :policy_shares
  has_many :forecasts
  has_many :messages, :as => :discussable
  has_many :requirements
  has_many :outstanding_requirements, :class_name => 'Requirement', :conditions => "description <> 'Case Notes' AND completed_at IS NULL", :foreign_key => "sale_case_id"
  has_many :quotes
  # .activities are those activities created directly from this case
  has_many :activities, :as => :trackable
  # .all_activities includes any activity related to this case, ie including those for its requirements, notes, messages
  has_many :all_activities, :class_name => 'Activity', :foreign_key => "sale_case_id"
  has_one :xylograph_policy
  has_many :xylograph_statuses

  TERM_CODES = %w[ PAID NTKN DECL REPL BKPD ]

  # TODO: Not sure why we need :policy_number unique and besides the allow_nil and allow_blank don't make sense.
  # Disabling for now during xylograph import transition period because it's causing us to miss a lot
  # of policies from xylograph.

  # validates_uniqueness_of :policy_number, :allow_nil => true, :allow_blank => true

  validates_presence_of :insured_last_name, :insured_first_name, :workflow_state, :policy_type

  attr_accessible :name,
                  :insurer,
                  :us_state,
                  :owner_last_name,
                  :owner_first_name,
                  :insured_dob,
                  :insured_gender,
                  :insured_occupation,
                  :insured_occupation_class,
                  :insured_email,
                  :insured_website,
                  :nbu_coordinator_id,
                  :nbu_processor_id,
                  :aasm_state,
                  :policy_number,
                  :insured_last_name,
                  :insured_first_name,
                  :policy_type,
                  :billing_mode,
                  :line_of_business,
                  :cash,
                  :plan,
                  :mode,
                  :puapui,
                  :status,
                  :status_date,
                  :total_amount,
                  :total_annual_premium,
                  :total_annual_premium_issued,
                  :glic_underwriter_id,
                  :glic_coordinator_id,
                  :glic_supervisor_id,
                  :advisor_id,
                  :primary_advisor,
                  :workflow_state,
                  :product_type,
                  :actions,
                  :stp_application_num,
                  :app_signed_date,
                  :rider_fio,
                  :rider_fio_amount,
                  :benefit_period,
                  :benefit_elim_period,
                  :riders_options,
                  :discounts,
                  :cash_collected,
                  :cash_amount,
                  :cash_returned,
                  :special_request,
                  :premium_mode,
                  :sale_case_shares_attributes,
                  :callctr_processor_id,
                  :case_origination,
                  :agent_identifier,
                  :windsor_ident,
                  :xyl_policy_identifier,
                  :submit_to_glic_date,
                  :request_source,
                  :request_info,
                  :tap_iss_pua_unsched,
                  :tap_iss_pua_sched,
                  :tap_iss_1035,
                  :tap_iss_qterm,
                  :tap_sub_pua_unsched,
                  :tap_sub_pua_sched,
                  :tap_sub_1035,
                  :tap_sub_qterm,
                  :sent_to_producer_date,
                  :received_in_agency_date,
                  :exam_signed_date,
                  :lab_slip_signed_date,
                  :month_end_close_possible,
                  :face_amount_is_hlv,
                  :sst_responsible

  attr_accessor :current_user

  scoped_search :on => [:policy_number, :insured_last_name, :insured_first_name]
  scoped_search :in => :producers, :on => [:last_name, :first_name]
  scoped_search :in => :nbu_coordinator, :on => [:last_name, :first_name]

  # Anonymous named_scope
  named_scope :conditions, lambda { |*args| {:conditions => args} }

  # For some bizarre reason, the combined quick search scope is almost two orders of magnitude slower than the three that follow it.
  # Better to combine the results of the three.
  named_scope :quick_search, lambda {|term| { :joins => "INNER JOIN sale_case_shares ON sale_cases.id = sale_case_shares.sale_case_id
    INNER JOIN users ON users.id = sale_case_shares.producer_id
    LEFT OUTER JOIN users AS nbu_coordinators ON nbu_coordinators.id = sale_cases.nbu_coordinator_id", :order => "sale_cases.updated_at DESC",
   :conditions => ["sale_cases.policy_number LIKE :search_term OR sale_cases.insured_last_name LIKE :search_term OR sale_cases.insured_first_name LIKE :search_term
    OR users.last_name LIKE :search_term OR users.first_name LIKE :search_term OR nbu_coordinators.first_name LIKE :search_term OR nbu_coordinators.last_name LIKE :search_term",
    {:search_term => "#{term}%"}] }}
  named_scope :quick_search_on_case, lambda {|term| { :joins => "INNER JOIN sale_case_shares ON sale_cases.id = sale_case_shares.sale_case_id
    INNER JOIN users ON users.id = sale_case_shares.producer_id
    LEFT OUTER JOIN users AS nbu_coordinators ON nbu_coordinators.id = sale_cases.nbu_coordinator_id", :order => "sale_cases.updated_at DESC",
   :conditions => ["sale_cases.policy_number LIKE :search_term OR sale_cases.insured_last_name LIKE :search_term OR sale_cases.insured_first_name LIKE :search_term",
    {:search_term => "#{term}%"}] }}
  named_scope :quick_search_on_user, lambda {|term| { :joins => "INNER JOIN sale_case_shares ON sale_cases.id = sale_case_shares.sale_case_id
    INNER JOIN users ON users.id = sale_case_shares.producer_id
    LEFT OUTER JOIN users AS nbu_coordinators ON nbu_coordinators.id = sale_cases.nbu_coordinator_id", :order => "sale_cases.updated_at DESC",
   :conditions => ["users.last_name LIKE :search_term OR users.first_name LIKE :search_term",
    {:search_term => "#{term}%"}] }}
  named_scope :quick_search_on_nbu, lambda {|term| { :joins => "INNER JOIN sale_case_shares ON sale_cases.id = sale_case_shares.sale_case_id
    INNER JOIN users ON users.id = sale_case_shares.producer_id
    LEFT OUTER JOIN users AS nbu_coordinators ON nbu_coordinators.id = sale_cases.nbu_coordinator_id", :order => "sale_cases.updated_at DESC",
   :conditions => ["nbu_coordinators.first_name LIKE :search_term OR nbu_coordinators.last_name LIKE :search_term",
    {:search_term => "#{term}%"}] }}

  # duplication is somewhat ugly, but you can't alias named scopes
  named_scope :policies, :conditions => 'policy_number IS NOT NULL'

  columns_for_list = "id, policy_type, policy_number, insured_last_name, insured_first_name, workflow_state, total_amount, total_annual_premium, total_annual_premium_issued, status_date, responsible_staff_id, glic_underwriter_id, updated_at, tap_sub_pua_unsched, tap_sub_pua_sched, tap_sub_1035, tap_sub_qterm, tap_iss_pua_unsched, tap_iss_pua_sched, tap_iss_1035, tap_iss_qterm, month_end_close_possible, face_amount_is_hlv"

  named_scope :opportunity, :conditions => "workflow_state IN ('quote_requested', 'illustration_sent', 'info_requested')", :order => "total_annual_premium DESC"
  named_scope :opportunity_for_list, :select => columns_for_list, :conditions => "workflow_state IN ('quote_requested', 'illustration_sent', 'info_requested')", :order => "total_annual_premium DESC"
  named_scope :application, :conditions => "workflow_state IN ('application_received', 'application_hold', 'application_hold_licensing', 'change_requested')", :order => "total_annual_premium DESC"
  named_scope :application_for_list, :select => columns_for_list, :conditions => "workflow_state IN ('application_received', 'application_hold', 'application_hold_licensing', 'change_requested')", :order => "total_annual_premium DESC"
  named_scope :underwriting, :conditions => "workflow_state IN ('pending', 'awaiting_review', 'informal_inquiry', 'to_reinsurance', 'awaiting_formal_app', 'tentative_offer', 'submitted', 'approved', 'awaiting_issue', 'change_pending', 'reissue_requested')", :order => "total_annual_premium DESC"
  named_scope :underwriting_for_list, :select => columns_for_list, :conditions => "workflow_state IN ('pending', 'awaiting_review', 'informal_inquiry', 'to_reinsurance', 'awaiting_formal_app', 'tentative_offer', 'submitted', 'approved', 'awaiting_issue', 'change_pending', 'reissue_requested')", :order => "total_annual_premium DESC"
  named_scope :issuance, :conditions => "workflow_state IN ('gone_to_issue', 'issued_not_paid')", :order => "total_annual_premium DESC"
  named_scope :issuance_for_list, :select => columns_for_list, :conditions => "workflow_state IN ('gone_to_issue', 'issued_not_paid')", :order => "total_annual_premium DESC"
  named_scope :delivery, :conditions => "workflow_state IN ('advanced', 'delivered')", :order => "total_annual_premium DESC"
  named_scope :delivery_for_list, :select => columns_for_list, :conditions => "workflow_state IN ('advanced', 'delivered')", :order => "total_annual_premium DESC"
  named_scope :inforce, :conditions => "workflow_state IN ('inforce', 'paid', 'change_completed')", :order => "total_annual_premium DESC"
  named_scope :inforce_for_list, :select => columns_for_list, :conditions => "workflow_state IN ('inforce', 'paid', 'change_completed')", :order => "total_annual_premium DESC"
  named_scope :closed, :conditions => "workflow_state IN ('call_center_closed', 'declined', 'not_taken_cost', 'not_taken_rating', 'not_taken_other','closed_incomplete', 'withdrawn', 'postponed', 'change_declined', 'change_cancelled', 'unknown')", :order => "total_annual_premium DESC"
  named_scope :closed_for_list, :select => columns_for_list, :conditions => "workflow_state IN ('call_center_closed', 'declined', 'not_taken_cost', 'not_taken_rating', 'not_taken_other','closed_incomplete', 'withdrawn', 'postponed', 'change_declined', 'change_cancelled', 'unknown')", :order => "total_annual_premium DESC"
  named_scope :all_for_list, :select => columns_for_list, :conditions => "workflow_state NOT IN ('unknown')", :order => "total_annual_premium DESC"
  named_scope :paid_last_30_days, :conditions => ["workflow_state = 'paid' and sale_cases.updated_at > ?", 1.month.ago], :order => "updated_at DESC"
  named_scope :paid_last_30_days_for_list, :select => columns_for_list, :conditions => ["workflow_state = 'paid' and sale_cases.updated_at > ?", 1.month.ago], :order => "updated_at DESC"
  named_scope :paid_last_2_weeks, :conditions => ["workflow_state = 'paid' and sale_cases.updated_at > ?", 2.weeks.ago], :order => "updated_at DESC"
  named_scope :paid_last_2_weeks_for_list, :select => columns_for_list, :conditions => ["workflow_state = 'paid' and sale_cases.updated_at > ?", 2.weeks.ago], :order => "updated_at DESC"

  named_scope :unknown, :conditions => "workflow_state IN ('unknown')", :order => "total_annual_premium DESC"
  named_scope :all_processing_stages, :conditions => "workflow_state IN ('quote_requested', 'illustration_sent', 'info_requested', 'application_received', 'application_hold', 'application_hold_licensing', 'change_requested', 'pending', 'awaiting_review', 'informal_inquiry', 'to_reinsurance', 'awaiting_formal_app', 'tentative_offer', 'submitted', 'approved', 'awaiting_issue', 'change_pending', 'reissue_requested', 'gone_to_issue', 'issued_not_paid', 'advanced', 'delivered')"
  named_scope :all_processing_stages_for_list, :select => "id, policy_type, policy_number, insured_last_name, insured_first_name", :conditions => "workflow_state IN ('quote_requested', 'illustration_sent', 'info_requested', 'application_received', 'application_hold', 'application_hold_licensing', 'change_requested', 'pending', 'awaiting_review', 'informal_inquiry', 'to_reinsurance', 'awaiting_formal_app', 'tentative_offer', 'submitted', 'approved', 'awaiting_issue', 'change_pending', 'reissue_requested', 'gone_to_issue', 'issued_not_paid', 'advanced','delivered')"
  named_scope :nbu_processing_stages, :conditions => "workflow_state IN ('quote_requested', 'illustration_sent', 'info_requested', 'application_received', 'application_hold', 'application_hold_licensing', 'change_requested', 'pending', 'awaiting_review', 'informal_inquiry', 'to_reinsurance', 'awaiting_formal_app', 'tentative_offer', 'submitted', 'approved', 'awaiting_issue', 'change_pending', 'reissue_requested', 'gone_to_issue', 'issued_not_paid', 'advanced', 'delivered')", :order => "total_annual_premium DESC"
  named_scope :call_center_processing_stages, :conditions => "workflow_state IN ('quote_requested', 'illustration_sent', 'info_requested')"
  named_scope :dead, :conditions => "workflow_state IN ('dead')"
  named_scope :all_pending, :conditions => "workflow_state IN ('application_received', 'application_hold', 'application_hold_licensing', 'pending', 'awaiting_review', 'informal_inquiry', 'to_reinsurance', 'awaiting_formal_app', 'tentative_offer', 'submitted', 'approved', 'awaiting_issue', 'gone_to_issue', 'issued_not_paid', 'reissue_requested', 'advanced', 'delivered')", :order => "total_annual_premium DESC"

  named_scope :issued_not_paid, :conditions => "workflow_state IN ('issued_not_paid')", :order => "status_date ASC"
  named_scope :issued_not_paid_for_list, :select => columns_for_list, :conditions => "workflow_state IN ('issued_not_paid')", :order => "status_date ASC"
  named_scope :approved, :conditions => "workflow_state IN ('approved')", :order => "total_annual_premium DESC"

  named_scope :for_nbc, lambda {|nbc| {:conditions => {:nbu_user => nbc}}}
  named_scope :for_responsible_staff, lambda {|user| {:conditions => ["responsible_staff_id = ?", user.id ]}}

  named_scope :windsor_processing, :conditions => ["case_origination = 'W' AND workflow_state IN ('application_received', 'gone_to_issue', 'pending', 'unknown')"], :order => "status_date DESC"
  named_scope :windsor_closed, :conditions => ["case_origination = 'W' AND workflow_state IN ('windsor_closed')"], :order => "status_date DESC"


  named_scope :fuzzy_search, lambda {|search_term| {:include => [:advisors, :quotes],
    :conditions => ["sale_cases.policy_number LIKE :term OR sale_cases.owner_first_name LIKE :term OR sale_cases.owner_last_name LIKE :term OR users.first_name LIKE :term OR users.last_name LIKE :term or quotes.ins1_first LIKE :term or quotes.ins1_last LIKE :term or quotes.ins2_first LIKE :term or quotes.ins2_last LIKE :term", {:term => "#{search_term}%"}]
  }}
  named_scope :first_last_fuzzy_search, lambda {|search_term1, search_term2| {:include => [:advisors, :quotes],
    :conditions => ["sale_cases.policy_number LIKE :first OR sale_cases.policy_number LIKE :last OR sale_cases.owner_first_name LIKE :first OR sale_cases.owner_last_name LIKE :last OR users.first_name LIKE :first OR users.last_name LIKE :last or quotes.ins1_first LIKE :first or quotes.ins1_last LIKE :last or quotes.ins2_first LIKE :first or quotes.ins2_last LIKE :last", {:first => "#{search_term1}%", :last => "#{search_term2}%"}]
  }}
  named_scope :for_producer, lambda{|producer| {:include => [:advisors], :conditions => ["users.id = ?", producer.id]}}
  named_scope :for_a_producer, lambda{|producer| {:include => [:producers], :conditions => ["users.id = ?", producer.id]}}
  named_scope :for_team, lambda{|team| {:include => [:advisors], :conditions => ["users.id IN (?)", team.members.map(&:id)]}}

  named_scope :life, :conditions => "policy_type = 'Life'"
  named_scope :disability, :conditions => "policy_type = 'DI'"
  named_scope :long_term_care, :conditions => "policy_type = 'LTC'"

  named_scope :ctm_targeted, :conditions => 'month_end_close_possible IS TRUE'
  named_scope :handled_by_sst, :conditions => 'sst_responsible is TRUE'
  named_scope :not_handled_by_sst, :conditions => 'sst_responsible is FALSE OR sst_responsible is NULL'

  named_scope :paid_this_week, :conditions => ["status = 'paid' AND YEAR(status_date) = :year AND WEEK(status_date) = :week", { :year => Date.today.year, :week => Date.today.cweek }]
  named_scope :paid_this_month, :conditions => ["status = 'paid' and YEAR(status_date) = :year AND MONTH(status_date) = :month", { :year => Date.today.year, :month => Date.today.month }]
  named_scope :paid_this_year, :conditions => ["status = 'paid' and YEAR(status_date) = :year", { :year => Date.today.year }]

  named_scope :status_date_this_year, :conditions => ["status_date > ?", Date.today << 12]

  named_scope :updated_since, lambda{|updated_time| {:conditions => ["sale_cases.updated_at > ?", updated_time]}}
  named_scope :status_updated_since, lambda{|updated_time| {:conditions => ["sale_cases.status_date > ?", updated_time]}}
  named_scope :requirement_updated_since, lambda{|updated_time| {:include => :requirements, :conditions => ["requirements.updated_at > ?", updated_time]}}
  named_scope :note_updated_since, lambda{|updated_time| {:include => {:requirements => :notes}, :conditions => ["notes.updated_at > ?", updated_time]}}
  named_scope :attachment_updated_since, lambda{|updated_time| {:include => :sale_case_attachments, :conditions => ["producer_viewable = ? and sale_case_attachments.updated_at > ?", 1, updated_time]}}
  named_scope :message_updated_since, lambda{|updated_time| {:include => :messages, :conditions => ["messages.updated_at > ?", updated_time]}}

  named_scope :with_shares_and_outstanding_requirements, :include => [:nbu_coordinator, :outstanding_requirements, {:sale_case_shares => :producer}]
  named_scope :with_outstanding_requirements, :include => [:outstanding_requirements]

  named_scope :not_blocked_from_producer, :conditions => "sale_case_shares.hide_from_producer IS NULL or sale_case_shares.hide_from_producer = 0"
  named_scope :by_producer_company, lambda{|company| {:include => :producers, :conditions => ["users.company LIKE ?", "%#{company}%"]}}

  named_scope :with_policy, :conditions => "policy_id is NOT NULL", :order => "status_date DESC"
  named_scope :with_no_policy, :conditions => "policy_id is NULL", :order => "status_date DESC"

  after_create :create_default_forecast, :create_default_requirement
  before_save :create_state_change_note
  after_create :create_activity_for_new
  before_save :create_activity
  before_save :set_responsible_staff

  include Workflow
  workflow do
  # ===== Stage 1 - Opportunity =====

    # Prior to application processing
    state :quote_requested do
      # Triggered by a quote submission from the Producer. A new case will be created if it's labeled as "Start a new case"
      event :send_illustration, :transitions_to => :illustration_sent
    end

    state :info_requested do

    end

    state :illustration_sent do
      # Triggered by Call Center when the illustration (quote) is sent
      # event :send_application, :transitions_to => :app_received
    end

  # ===== Stage 2 - Application =====

    state :application_received do
      # Triggered by NBU when application is received from the producer
      # event :request_requirements, :transitions_to => :application_hold
      # event :submit_application, :transitions_to => :submitted_to_guardian
    end

    state :application_hold do
      # Triggered by NBU if the application has deficiencies that need to be fixed prior to submission
      # event :submit_application, :transitions_to => :submitted_to_guardian
    end

    state :application_hold_licensing do

    end

    state :change_requested do

    end

  # ===== Stage 3 - Underwriting =====
    # Submitted, waiting for GLIC approval

    state :pending do
      # event :tentatively_offerred, :transitions_to => :tentative_offer
    end

    state :awaiting_review do
    end

    state :to_reinsurance do
    end

    state :informal_inquiry do
    end

    state :awaiting_formal_app do
    end

    state :tentative_offer do
      # event :issue_policy, :transitions_to => :policy_issued
    end

    state :submitted do
    end

    state :approved do
    end

    state :awaiting_issue do
    end

    state :change_pending do
    end

    state :reissue_requested do
    end

  # ===== Stage 4 - Issuance =====
    # After GLIC approval

    state :gone_to_issue do
    end

    state :issued_not_paid do
    end

  # ===== Stage 5 - Delivery =====

    state :advanced do
    end

    state :delivered do
    end

  # ===== Stage 6 - In-Force =====

    state :paid do
    end

    # Paid or Berkshire Paid
    state :inforce do
      # Eventually Automatically triggered by PAID or BKPD from GLIC
      # The only way a case can make it to :inforce is through a successful 5.2 and a "PAID" or "BKPD" status assigned by Guardian
    end

    state :change_completed do
    end

  # ===== Stage 7 - Closed =====

    state :call_center_closed do
    end

    state :declined do
    end

    state :not_taken_cost do
    end

    state :not_taken_rating do
    end

    state :not_taken_other do
    end

    state :closed_incomplete do
    end

    state :withdrawn do
    end

    state :postponed do
    end

    state :change_declined do
    end

    state :change_cancelled do
    end

    state :windsor_closed do
    end

    state :unknown do
      # imports where initial status is dubious
    end

  end

  def display_state
    workflow_state.to_s.titleize
  end

  def stage
    case workflow_state.to_sym
    when :quote_requested, :illustration_sent, :info_requested
      :opportunity
    when :application_received, :application_hold, :application_hold_licensing, :change_requested
      :application
    when :pending, :awaiting_review, :informal_inquiry, :to_reinsurance, :awaiting_formal_app, :tentative_offer, :submitted, :approved, :awaiting_issue, :change_pending, :reissue_requested
      :underwriting
    when :gone_to_issue, :issued_not_paid
      :issuance
    when :advanced, :delivered
      :delivery
    when :inforce, :paid, :change_completed
      :inforce
    when :call_center_closed, :declined, :not_taken_cost, :not_taken_rating, :not_taken_other, :closed_incomplete, :withdrawn, :postponed, :change_declined, :change_cancelled, :windsor_closed
      :closed
    when :unknown
      :unknown
    end
  end

  def display_stage
    stage.to_s.titleize
  end

  def responsibility_assignment
    case stage
    when :opportunity
      callctr_processor
    when :application
      nbu_coordinator.nil? ? nbu_processor : nbu_coordinator
    when :underwriting
      nbu_coordinator.nil? ? nbu_processor : nbu_coordinator
    when :issuance
      nbu_processor.nil? ? nbu_coordinator : nbu_processor
    when :delivery
      nbu_processor.nil? ? nbu_coordinator : nbu_processor
    end
  end

  def is_responsible?(user)
    user.id == responsible_staff_id
  end

  # This is used as a fallback by default_message_recipient if it
  # can't find a user based on the workflow state.
  def message_recipient_from_case_type
    account = producers.first.account
    user_id = case policy_type
    when "DI"
      account.di_service_user_id
    when "Life"
      account.life_service_user_id
    when "LTC"
      account.ltc_service_user_id
    else
      account.inquiries_user_id
    end
    if user_id
      User.find(user_id)
    else
      nil
    end
  end

  def accessible_by?(user)
    user.staff_access? || self.producers.include?(user) || self.is_supervised_by?(user)
  end

  def message_recipient_from_workflow_stage
    case stage
    when :opportunity
      callctr_processor
    else
      nbu_coordinator
    end
  end

  # Used when producer sends messages from within a SaleCase; depending
  # on workflow state or case type, route the message to the proper user.
  def default_message_recipient
    message_recipient_from_workflow_stage || message_recipient_from_case_type
  end

  def self.latest_entry_date
    # TODO Think about removing this.  Using the created_at to indicate freshness is a better indicator, rather than relying on external Guardian data integrity
    calculate(:max, :status_date)
  end

  def to_param
    last_name =
    if policy_type
      "#{id}-#{policy_type.gsub(/[^a-z0-9]+/i, '-')}-#{insured_last_name.gsub(/[^a-z0-9]+/i, '-')}".downcase
    else
      "#{id}-#{insured_last_name.gsub(/[^a-z0-9]+/i, '-')}".downcase
    end
  end

  def case_name
    if policy_number?
      policy_number
    else
      agency_designator = Account.first.agency_code[0..1].upcase
      case policy_type
      when "LTC"
        policy_prefix = "Z"
      when "DI"
        policy_prefix = "K"
      when "Info"
        policy_prefix = "I"
      else
        policy_prefix = "0"
      end
      "#{agency_designator}#{policy_prefix}#{"%06d" % id}"
    end
  end

  def case_long_name
    "#{case_name} (#{insured_last_name}, #{insured_first_name})"
  end

  def calculate_total_amount
    update_attribute(:total_amount, policy_shares.calculate(:sum, :total_basic_amount))
    return total_amount
  end

  def self.calculate_total_amount!
    success = true

    find(:all).each do |sale_case|
      sale_case.calculate_total_amount
      success &&= sale_case.save
    end

    success
  end

  def calculate_total_annual_premium
    self.total_annual_premium = self.policy_shares.calculate(:sum, :total_annual_premium)
  end

  def self.calculate_total_annual_premium!
    success = true

    find(:all).each do |sale_case|
      sale_case.calculate_total_annual_premium
      success &&= sale_case.save
    end

    success
  end

  def calculate_primary_advisor
    # TODO CONSIDER Equal shares
    if self.policy_shares.empty?
      self.primary_advisor = ''
    else
      list = self.primary_advisor = self.policy_shares.sort{|a,b| b.share <=> a.share}.select{|s| !s.advisor.nil?}
      if list.empty?
        self.primary_advisor = ''
      else
        self.primary_advisor = list.first.advisor.display_name
      end
    end
  end

  def self.calculate_primary_advisor!
    success = true

    find(:all).each do |sale_case|
      sale_case.calculate_primary_advisor
      success &&= sale_case.save
    end

    success
  end

  def short_display
    "#{policy_number} #{insured_last_name}".strip
  end

  def all_notes
    combined_notes = notes.all
    requirements.all.each do |requirement|
      combined_notes += requirement.notes.all
    end
    combined_notes
  end

  #---------- Actions Flag Management ----------------------------------------
  named_scope :with_action, lambda { |action| {:conditions => "actions_mask & #{2**ACTIONS.index(role.to_s)} > 0"} }

  # IMPORTANT: DO NOT modify this list except to add additional actions to the end.
  ACTIONS = [ 'alert',
              'nbu_action_needed',
              'producer_action_needed',
              'glic_action_needed',
              'client_action_needed'
            ]

  def actions=(actions)
    self.actions_mask = (actions & ACTIONS).map { |r| 2**ACTIONS.index(r) }.sum
  end

  def actions
    ACTIONS.reject { |r| ((actions_mask || 0) & 2**ACTIONS.index(r)).zero? }
  end

  def action?(action)
    actions.include? action.to_s
  end

  def create_default_forecast
    forecasts.create!(:date => Time.now+1.month, :amount => self.total_amount, :premium_amount => self.total_annual_premium) if forecasts.length == 0
  end

  def self.create_default_forecast
    all.map(&:create_default_forecast)
  end

  def create_default_requirement
    if requirements.empty?
      requirement = requirements.create(:description => 'Case Notes')
      requirement.update_attribute(:created_at, created_at)
    end
  end

  def create_initial_case_requirement
    if requirements.case_notes.empty?
      requirement = requirements.create(:description => 'Case Notes')
      requirement.update_attribute(:created_at, created_at)
    end
  end

  def self.create_default_requirement
    all.map(&:create_default_requirement)
  end

  def self.create_initial_case_requirement
    all.map(&:create_initial_case_requirement)
  end

  def is_supervised_by?(user)
    @supervises_producer = false
    self.producers.each do |producer|
      @supervises_producer = true if producer.is_supervised_by?(user)
    end
    @supervises_producer && user.is_broker_supervisor?
  end


  def self.check_for_policy
    all.pocessing_stages.with_no_policy.each_with_index do |sale_case|
      unless sale_case.policy_number.blank?
        policy = Policy.find_by_policy_num(sale_case.policy_number)
        if policy
          sale_case.policy_id = policy.id
        end
      end
    end
  end

  # def self.search(search, search_by, page)
  #   if search
  #     find(:all, :conditions => ["#{search_by} LIKE ? ", "%#{search}%"]).paginate(:per_page => 50, :page => page)
  #   end
  # end

  def merge_sale_case(other_case)
    self.name                   ||= other_case.name
    self.insurer                ||= other_case.insurer
    self.us_state               ||= other_case.us_state
    self.owner_last_name        ||= other_case.owner_last_name
    self.owner_first_name       ||= other_case.owner_first_name
    self.insured_dob              ||= other_case.insured_dob
    self.insured_gender           ||= other_case.insured_gender
    self.insured_occupation       ||= other_case.insured_occupation
    self.insured_occupation_class ||= other_case.insured_occupation_class
    self.insured_email            ||= other_case.insured_email
    self.insured_website          ||= other_case.insured_website
    self.nbu_coordinator_id     ||= other_case.nbu_coordinator_id
    self.policy_number          ||= other_case.policy_number
    self.insured_last_name      ||= other_case.insured_last_name
    self.insured_first_name     ||= other_case.insured_first_name
    self.policy_type            ||= other_case.policy_type
    self.billing_mode           ||= other_case.billing_mode
    self.line_of_business       ||= other_case.line_of_business
    self.cash                   ||= other_case.cash
    self.plan                   ||= other_case.plan
    self.mode                   ||= other_case.mode
    self.puapui                 ||= other_case.puapui
    self.status                 ||= other_case.status
    self.status_date            ||= other_case.status_date
    self.total_amount           ||= other_case.total_amount
    self.total_annual_premium   ||= other_case.total_annual_premium
    self.glic_underwriter_id    ||= other_case.glic_underwriter_id
    self.glic_coordinator_id    ||= other_case.glic_coordinator_id
    self.glic_supervisor_id     ||= other_case.glic_supervisor_id
    self.primary_advisor        ||= other_case.primary_advisor

    other_case.sale_case_relationships.update_all(:sale_case_id => id)
    SaleCaseRelationship.update_all({:related_sale_case_id => id}, ["related_sale_case_id = ?", other_case.id])
    other_case.sale_case_attachments.update_all(:sale_case_id => id)
    other_case.premiums.update_all(:sale_case_id => id)
    other_case.policy_events.update_all(:sale_case_id => id)
    other_case.policy_shares.update_all(:sale_case_id => id)
    other_case.forecasts.update_all(:sale_case_id => id)
    other_case.messages.update_all(:discussable_id => id)
    other_case.requirements.update_all(:sale_case_id => id)
    other_case.quotes.update_all(:sale_case_id => id)

    other_case.delete
    save!
  end

  def potential_matches
    SaleCase.find(:all, :conditions => ["id <> ? AND (insured_last_name = ? OR owner_last_name = ?)", id, insured_last_name, owner_last_name])
  end

  def app_expiration_date
    if app_signed_date
      case policy_type
      when "Life"
        expiration_date = app_signed_date + 6.months
      when "DI"
        expiration_date = app_signed_date + 90.days
      when "LTC"
        expiration_date = app_signed_date + 6.months
      else
        return nil
      end
    else
      return nil
    end
  end

  def exam_expiration_date
    if exam_signed_date
      expiration_date = exam_signed_date + 6.months
    else
      return nil
    end
  end

  def lab_slip_expiration_date
    if lab_slip_signed_date
      expiration_date = lab_slip_signed_date + 1.year
    else
      return nil
    end
  end

  def weeks_since_update
    Date.today.cweek - self.updated_at.to_datetime.cweek
  end

  def updated_this_week?
    self.updated_at.to_datetime.cweek == Date.today.cweek
  end

  def updated_since_last_week?
    self.updated_at.to_datetime.cweek >= Date.today.cweek - 1
  end

  def windsor_case?
    self.policy_type == 'WLife' || self.windsor_ident
  end

  def should_be_handled_by_sst?
    self.sst_responsible? && !AppSettings.special_support_team_initials.blank?
  end

  def premium_to_display
    if total_annual_premium_issued.blank?
      total_annual_premium.blank? ? 0 : total_annual_premium
    else
      total_annual_premium_issued
    end
  end

  def is_in_windsor_notify_state?
    %w(declined not_taken_cost not_taken_rating postponed).include?(self.workflow_state) && self.policy_type == "Life"
  end

  # Used to determine if a displayed premium should indicate whether or not it is made up of PUA, 1035 or Qterm dollars
  # TODO: Write tests for these (premium_is_composite?, has_submitted_premium_composites?, has_issued_premium_composites?)
  def premium_is_composite?
    total_annual_premium_issued.to_i > 0 ? has_issued_premium_composites? : has_submitted_premium_composites?
  end

  def has_submitted_premium_composites?
    (self.tap_sub_pua_unsched.to_i > 0) || (self.tap_sub_pua_sched.to_i > 0) || (self.tap_sub_1035.to_i > 0) || (self.tap_sub_qterm.to_i > 0)
  end

  def has_issued_premium_composites?
    (self.tap_iss_pua_unsched.to_i > 0) || (self.tap_iss_pua_sched.to_i > 0) || (self.tap_iss_1035.to_i > 0) || (self.tap_iss_qterm.to_i > 0)
  end

  PREM_MODE = [ 'Annually',
                'GOM/Monthly',
                'List Bill - Annually',
                'List Bill - Quarterly',
                'List Bill - Semi-Annually',
                'Monthly List Bill',
                'Quarterly',
                'Semi-Annually'
              ]

  PRODUCT_LIST =  [ '20 Pay',
                    '20 Payment Life',
                    '401K',
                    '412i',
                    'Achiever Gold Whole Life',
                    'Annuity',
                    'Berkshire Term',
                    'Berkshire UL',
                    'Business Reducing Term',
                    'Disability Buy-Out',
                    'Economix Perm',
                    'EstateGuard',
                    'EstateGuard SUL',
                    'Flex 15',
                    'Flexible Solutions VUL',
                    'Guaranteed Issue Whole Life',
                    'Guardian Flex 15',
                    'Guardian Level Term Gold',
                    'L121',
                    'L65',
                    'L95',
                    'L96',
                    'L99',
                    'Level Term',
                    'Life Paid-Up 65',
                    'Lifespan Gold',
                    'Limited Pay Whole Life',
                    'Long Term Care',
                    'Overhead Expense',
                    'PAL',
                    'Park Avenue SVUL - Millennium Series',
                    'Pension Trust',
                    'Personal Reducing Term',
                    'Provider Plus',
                    'PT Guar Issue WL3',
                    'PT Life Paid-Up at 96',
                    'PT Life Paid-Up at 97',
                    'PT The Guardian Resource Life',
                    'PT Whole Life 100',
                    'PT Whole Life 121',
                    'PT Whole Life 3',
                    'PT Whole Life 3 Gold',
                    'PT Whole Life 95',
                    'PT Whole Life 98',
                    'PT Whole Life 99',
                    'PT Yearly Renewable Term Gold',
                    'Reduced Paid Up',
                    'Resource Life',
                    'Supplemental Whole Life',
                    'The Guardian Resource Life',
                    'UltraLife Gold',
                    'UltraMax Gold',
                    'Universal Life Protector Gold',
                    'VIP',
                    'VUL',
                    'WL121',
                    'WL99',
                    'Yearly Renewable Term Gold',
                    'Other'
                    ]

  OCCUPATION_CLASS = [  '1',
                        '2',
                        '3',
                        '4',
                        '4P',
                        '5',
                        '6',
                        '2M',
                        '3M',
                        '4M',
                        '5M',
                        '6M',
                        '4A'
                      ]

  def responsible_sale_case_id
    id
  end

  def send_case_status_change_alert(status)
    if self.should_be_handled_by_sst?
      recipient = User.find(AppSettings.special_support_team_leader_id.to_i)
      Mailer.deliver_case_status_change_alert(recipient, self, status)
    else
      producers.wants_daily_case_email.has_email_address.each do |producer|
        Mailer.deliver_case_status_change_alert(producer, self, status)
      end
    end
    Mailer.deliver_case_status_change_alert(nbu_coordinator, self, status) unless nbu_coordinator.nil?
  end

  def self.clear_ctm_flags
    cleared_cases = []
    SaleCase.record_timestamps = false
    SaleCase.ctm_targeted.each do |sale_case|
      cleared_cases << "#{sale_case.id} - #{sale_case.case_long_name}"
      sale_case.update_attribute(:month_end_close_possible, false)
    end
    SaleCase.record_timestamps = true
    subject = "#{cleared_cases.size} Cases Cleared of Flag for CTM"
    message = "The following cases had their CTM flag cleared:<br />#{cleared_cases.join('<br />')}"
    Mailer.deliver_notify_super_admin(subject, message)
  end

# ------------- Private Methods ------------------------------------------------

private
  def reciprocate_relationship(related_sale_case)
    related_sale_case.related_sale_cases << self unless related_sale_case.related_sale_cases.include?(self)
  end

  def remove_relationship(related_sale_case)
    if related_sale_case.related_sale_cases.include?(self)
      related_sale_case.related_sale_cases.delete(self)
    end
  end

  # before_save
  def create_state_change_note
    if workflow_state_changed? && current_user
      if requirements && requirements.case_notes
        sale_case_id = self.id
        note = requirements.case_notes.first.notes.build(:comment =>"System: Case moved from #{workflow_state_was.to_s.titleize} to #{workflow_state.to_s.titleize} by #{current_user.display_name}", :user_id => current_user.id)
        note.access_level = 'broker'
        note.notable_id = sale_case_id
        note.sale_case_id = sale_case_id
        note.save
      end
    end
  end

  # after_create
  def create_activity_for_new
    activities.create(:change_type => "New", :description => "A new case was created.")
  end

  # before_save
  def create_activity
    if id && changed?
      descriptions = []
      changed.each do |change|
        descriptions << description_fragment(change)
      end
      activities.create(:change_type => "Changed", :description => "This case has changed: #{descriptions.compact.join(', ')}.")
    end
  end

  # before_save
  def set_responsible_staff
    self.responsible_staff_id = responsibility_assignment.nil? ? nil : responsibility_assignment.id
  end


  def description_fragment(attribute)
    case attribute
    when "id", "created_at", "updated_at"
      nil
    when "us_state"
      "State was changed from #{self.send(attribute + '_was')} to #{self.send(attribute)}"
    when "insured_dob"
      "Insured DOB was changed from #{self.send(attribute + '_was')} to #{self.send(attribute)}"
    when "nbu_coordinator_id"
      "NBU Coordinator was changed from #{User.find_by_id(self.send(attribute + '_was')).try(:display_name)} to #{User.find_by_id(self.send(attribute)).try(:display_name)}"
    else
      "#{attribute.titleize} was changed from #{self.send(attribute + '_was')} to #{self.send(attribute)}"
    end
  end

  def reject_nested_sale_case_share(params)
    params.all? { |k,v| v.blank? }
  end

end

# == Schema Information
#
# Table name: sale_cases
#
#  id                          :integer(4)      not null, primary key
#  name                        :string(255)
#  insurer                     :string(255)
#  us_state                    :string(255)
#  owner_last_name             :string(255)
#  owner_first_name            :string(255)
#  insured_dob                 :string(255)
#  insured_gender              :string(255)
#  insured_occupation          :string(255)
#  insured_occupation_class    :string(255)
#  insured_email               :string(255)
#  insured_website             :string(255)
#  nbu_coordinator_id          :integer(4)
#  policy_number               :string(255)
#  insured_last_name           :string(255)
#  insured_first_name          :string(255)
#  policy_type                 :string(255)
#  billing_mode                :string(255)
#  line_of_business            :string(255)
#  cash                        :decimal(8, 2)
#  plan                        :string(255)
#  mode                        :string(255)
#  puapui                      :string(255)
#  status                      :string(255)
#  status_date                 :date
#  total_amount                :decimal(10, 2)
#  total_annual_premium        :decimal(10, 2)
#  created_at                  :datetime
#  updated_at                  :datetime
#  glic_underwriter_id         :integer(4)
#  glic_coordinator_id         :integer(4)
#  glic_supervisor_id          :integer(4)
#  policy_id                   :integer(4)
#  advisor_id                  :integer(4)
#  primary_advisor             :string(255)
#  workflow_state              :string(255)
#  product_type                :string(255)
#  actions_mask                :integer(4)
#  case_origination            :string(255)
#  nbu_processor_id            :integer(4)
#  stp_application_num         :string(255)
#  workflow_state_note         :text
#  app_signed_date             :date
#  rider_fio                   :boolean(1)
#  rider_fio_amount            :string(255)
#  benefit_period              :string(255)
#  benefit_elim_period         :string(255)
#  riders_options              :string(255)
#  discounts                   :string(255)
#  cash_collected              :boolean(1)
#  cash_amount                 :string(255)
#  cash_returned               :boolean(1)
#  special_request             :text
#  premium_mode                :string(255)
#  total_annual_premium_issued :decimal(10, 2)
#  callctr_processor_id        :integer(4)
#  windsor_ident               :string(255)
#  xyl_policy_identifier       :string(255)
#  submit_to_glic_date         :date
#  request_source              :string(255)
#  request_info                :text
#
# Indexes
#
#  index_sale_cases_on_nbu_processor_id      (nbu_processor_id)
#  index_sale_cases_on_callctr_processor_id  (callctr_processor_id)
#  index_sale_cases_on_glic_coordinator_id   (glic_coordinator_id)
#  index_sale_cases_on_glic_supervisor_id    (glic_supervisor_id)
#  index_sale_cases_on_glic_underwriter_id   (glic_underwriter_id)
#  index_sale_cases_on_nbu_coordinator_id    (nbu_coordinator_id)
#
