# See "doc/LICENSE" for the license governing this code.

# == Schema Information
#
# Table name: premiums
#
#  id               :integer(4)      not null, primary key
#  lc_premium       :decimal(10, 2)  default(0.0)
#  ml_premium       :decimal(10, 2)  default(0.0)
#  bu_premium       :decimal(10, 2)  default(0.0)
#  bt_premium       :decimal(10, 2)  default(0.0)
#  di_premium       :decimal(10, 2)  default(0.0)
#  sl_premium       :decimal(10, 2)  default(0.0)
#  life_premium     :decimal(10, 2)  default(0.0)
#  agent_share      :decimal(10, 2)  default(0.0)
#  guardian_num     :string(255)
#  billing_mode     :string(255)
#  line_of_business :string(255)
#  mgr_code         :string(255)
#  writing_code     :string(255)
#  policy_id        :integer(4)
#  advisor_id       :integer(4)
#  event_date       :date
#  created_at       :datetime
#  updated_at       :datetime
#  life_share       :decimal(8, 2)   default(0.0)
#  di_share         :decimal(8, 2)   default(0.0)
#  sl_share         :decimal(8, 2)   default(0.0)
#  bu_share         :decimal(8, 2)   default(0.0)
#  bt_share         :decimal(8, 2)   default(0.0)
#  ml_share         :decimal(8, 2)   default(0.0)
#  lc_share         :decimal(8, 2)   default(0.0)
#  sale_case_id     :integer(4)
#
# Indexes
#
#  index_payment_events_on_policy_id   (policy_id)
#  index_payment_events_on_advisor_id  (advisor_id)
#  index_payment_events_on_event_date  (event_date)
#  index_premiums_on_policy_id         (policy_id)
#  index_premiums_on_advisor_id        (advisor_id)
#  index_premiums_on_sale_case_id      (sale_case_id)
#

class ImportError < StandardError; end

class Premium < ActiveRecord::Base
  set_table_name 'premiums'
  # LIFE == life_premium, sl_premium, bt_premium, bu_premium
  # DI   == di_premium, ml_premium
  # LTC  == lc_premium

  # module Total
  #   def total
  #     self.first.total
  #   end
  # end
  belongs_to :sale_case
  belongs_to :advisor, :class_name => 'User'

  named_scope :between_dates, lambda {|date1, date2| {:conditions => ["event_date BETWEEN ? AND ?", date1.is_a?(Date) ? date1 : Date.parse(date1), date2.is_a?(Date) ? date2 : Date.parse(date2)]}}
  named_scope :year, lambda {|year| {:conditions => ["YEAR(event_date) = ?", year]} }
  named_scope :year_or_null, lambda {|year| {:conditions => ["YEAR(event_date) = ? OR event_date IS NULL", year]} }
  named_scope :thru_month, lambda {|month| {:conditions => ["MONTH(event_date) <= ?", month]} }
  named_scope :month, lambda {|month| {:conditions => ["MONTH(event_date) = ?", month]}}
  # NOTE: quarter_from_month named scope takes a month, not a quarter number
  named_scope :quarter_from_month, lambda {|month| {:conditions => ["MONTH(event_date) BETWEEN ? AND ?", Statusroom.quarter_start(month), Statusroom.quarter_end(month)]}}
  months_by_quarter = [[1,2,3],[4,5,6],[7,8,9],[10,11,12]]
  named_scope :quarter,      lambda {|q| {:conditions => ["MONTH(event_date) IN (?)",  months_by_quarter[q-1] ]}}
  named_scope :date, lambda {|date| {:conditions => ["event_date = ?", date.is_a?(Date) ? date : Date.parse(date)]}}
  named_scope :start_date, lambda {|date| {:conditions => ["event_date >= ?", date.is_a?(Date) ? date : Date.parse(date)]} }
  named_scope :end_date,   lambda {|date| {:conditions => ["event_date <= ?", date.is_a?(Date) ? date : Date.parse(date)]}}
  named_scope :for_advisor, lambda {|who| {:conditions => ["guardian_num = ?", (who.is_a?(User) ? who.guardian_num : who) ] } }
  # TODO - This is not very robust.  What happens when team members don't have Guardian Nums???  It returns inaccurate results...
  named_scope :for_team, lambda {|team| {:conditions => ["guardian_num IN (?)", team.members_with_guardian_nums.map(&:guardian_num).compact ] } }
  named_scope :for_team_type, lambda { |type| { :conditions => ["teams.team_type in (?)", type =~ /All/ ? %w(General CDS Territory Class) : type ] }}
  named_scope :year_list, {:select => "DISTINCT(YEAR(event_date)) as year" }

  # named_scope :for, lambda { |whom|
  #   for_advisor(whom) # if whom.is_a? User
  #    #    for_team(whom) if whom.is_a? Team
  #   # all if whom.nil?
  # }
  named_scope :sum_total, {:group => 'guardian_num', :select => "*, YEAR(event_date) as year, MONTH(event_date) as month, SUM(life_premium + sl_premium + bt_premium + bu_premium + ml_premium + lc_premium + di_premium) as total" }
  named_scope :product_totals, {:select => "SUM(life_premium + sl_premium + bt_premium + bu_premium) as life_total, SUM(di_premium + ml_premium) as di_total, SUM(lc_premium) as lc_total, SUM(life_premium + sl_premium + bt_premium + bu_premium + ml_premium + lc_premium + di_premium) as grand_total"}
  named_scope :monthlies, {:group => 'year,month', :select => "*, YEAR(event_date) as year, MONTH(event_date) as month, SUM(life_premium + sl_premium + bt_premium + bu_premium + ml_premium + lc_premium + di_premium) as total, SUM(life_premium + sl_premium + bt_premium + bu_premium) as life, SUM(di_premium + ml_premium) as di_premium, SUM(lc_premium) as lc_premium"} do

    def to_chart_data
      chart_data = [nil] * 12
      chart_data.each_with_index do |e, i|
        if found = detect{|d| d.month.to_i == i+1 }
          chart_data[i] = {:total => BigDecimal(found.total.to_s), :life => BigDecimal(found.life.to_s), :di => BigDecimal(found.di_premium.to_s), :ltc => BigDecimal(found.lc_premium.to_s) }
        end
      end
      chart_data
    end

  end

  named_scope :dailies, {:group => 'day', :select => "*, DAY(event_date) as day, SUM(life_premium + sl_premium + bt_premium + bu_premium + ml_premium + lc_premium + di_premium) as total, SUM(life_premium + sl_premium + bt_premium + bu_premium) as life, SUM(di_premium + ml_premium) as di_premium, SUM(lc_premium) as lc_premium"} do

    def to_chart_data
      days = (self.first.event_date.beginning_of_month - self.first.event_date.end_of_month).to_i.abs rescue 30
      chart_data = [nil] * (days+1)
      chart_data.each_with_index do |e, i|
        if found = detect{|d| d.day.to_i == i+1 }
          chart_data[i] = {:total => BigDecimal(found.total.to_s), :life => BigDecimal(found.life.to_s), :di => BigDecimal(found.di_premium.to_s), :ltc => BigDecimal(found.lc_premium.to_s) }
        end
      end
      chart_data
    end

  end

  named_scope :quarter_dailies, {:group => 'month, day', :select => "*, DAYOFYEAR(event_date) as day_of_year, DAY(event_date) as day, MONTH(event_date) as month, SUM(life_premium + sl_premium + bt_premium + bu_premium + ml_premium + lc_premium + di_premium) as total, SUM(life_premium + sl_premium + bt_premium + bu_premium) as life, SUM(di_premium + ml_premium) as di_premium, SUM(lc_premium) as lc_premium"} do

    def to_chart_data
      days = (self.first.event_date.beginning_of_quarter - self.first.event_date.end_of_quarter).to_i.abs rescue 90
      first_day_of_year = self.first.day_of_year
      chart_data = [nil] * (days+1)
      chart_data.each_with_index do |e, i|
        if found = detect{|d| (d.day_of_year.to_i - first_day_of_year.to_i) == i }
          chart_data[i] = {:total => BigDecimal(found.total.to_s), :life => BigDecimal(found.life.to_s), :di => BigDecimal(found.di_premium.to_s), :ltc => BigDecimal(found.lc_premium.to_s) }
        end
      end
      chart_data
    end

  end

  named_scope :weeklies, {:group => 'year,week', :select => "*, YEAR(event_date) as year, WEEK(event_date) as week, SUM(life_premium + sl_premium + bt_premium + bu_premium + ml_premium + lc_premium + di_premium) as total, SUM(life_premium + sl_premium + bt_premium + bu_premium) as life_premium, SUM(di_premium + ml_premium) as di_premium, SUM(lc_premium) as lc_premium"}
  named_scope :performance, {:group => 'year', :select => "YEAR(event_date) as year, SUM(life_premium + sl_premium + bt_premium + bu_premium + ml_premium + lc_premium + di_premium) as all_premiums, SUM(life_premium + sl_premium + bt_premium + bu_premium) as life_premium, SUM(di_premium + ml_premium) as di_premium, SUM(lc_premium) as lc_premium" }
  named_scope :performance_for_career, {:group => 'year', :select => "YEAR(event_date) as year, SUM(life_premium + sl_premium + bt_premium + bu_premium + ml_premium + lc_premium + di_premium) as all_premiums, SUM(life_premium + sl_premium + bt_premium + bu_premium) as life_premium, SUM(di_premium + ml_premium) as di_premium, SUM(lc_premium) as lc_premium", :joins => 'LEFT OUTER JOIN users ON users.id = premiums.advisor_id', :conditions => "users.contract_type IN ('FR EXP', 'FR INEXP', 'SPECIAL AGENT', 'MGR', 'FMR')" }
  named_scope :performance_for_brokerage, {:group => 'year', :select => "YEAR(event_date) as year, SUM(life_premium + sl_premium + bt_premium + bu_premium + ml_premium + lc_premium + di_premium) as all_premiums, SUM(life_premium + sl_premium + bt_premium + bu_premium) as life_premium, SUM(di_premium + ml_premium) as di_premium, SUM(lc_premium) as lc_premium", :joins => 'LEFT OUTER JOIN users ON users.id = premiums.advisor_id', :conditions => "users.contract_type IN ('SPEC BKR', 'FTA', 'FP') OR (users.contract_type IS NULL)" }
  named_scope :performance_for_producers, {:group => 'year', :select => "YEAR(event_date) as year, SUM(life_premium + sl_premium + bt_premium + bu_premium + ml_premium + lc_premium + di_premium) as all_premiums, SUM(life_premium + sl_premium + bt_premium + bu_premium) as life_premium, SUM(di_premium + ml_premium) as di_premium, SUM(lc_premium) as lc_premium", :joins => 'LEFT OUTER JOIN users ON users.id = premiums.advisor_id', :conditions => "users.contract_type IN ('FR EXP', 'FR INEXP', 'SPECIAL AGENT', 'MGR', 'SPEC BKR', 'FTA', 'FP') OR (users.contract_type IS NULL)" }
  named_scope :performance_by_agent, {:group => 'guardian_num', :select => "guardian_num, SUM(life_premium + sl_premium + bt_premium + bu_premium + ml_premium + lc_premium + di_premium) as all_premiums, SUM(life_premium + sl_premium + bt_premium + bu_premium) as life_premium, SUM(di_premium + ml_premium) as di_premium, SUM(lc_premium) as lc_premium", :order => "all_premiums DESC" }
  named_scope :performance_by_team, { :group => 'teams.id', :joins => "RIGHT OUTER JOIN users ON premiums.guardian_num = users.guardian_num INNER JOIN team_memberships ON users.id = team_memberships.member_id RIGHT OUTER JOIN teams on team_memberships.team_id = teams.id", :select => "teams.*, SUM(life_premium + sl_premium + bt_premium + bu_premium + ml_premium + lc_premium + di_premium) as all_premiums, SUM(life_premium + sl_premium + bt_premium + bu_premium) as life_premium, SUM(di_premium + ml_premium) as di_premium, SUM(lc_premium) as lc_premium, teams.name"  }

  # This one might create namespace issues with life_premium if combined with other scopes...
  named_scope :with_totals, {:select => '*, (life_premium + sl_premium + bt_premium + bu_premium + ml_premium + lc_premium + di_premium) as total, (life_premium + sl_premium + bt_premium + bu_premium) as life_premium'}

  named_scope :has_negative_premium, :conditions => "lc_premium < 0 OR ml_premium < 0 OR bu_premium < 0 OR bt_premium < 0 or di_premium < 0 OR sl_premium < 0 OR life_premium < 0"

  def self.life
    calculate(:sum, :life_premium) + calculate(:sum, :sl_premium) + calculate(:sum, :bt_premium) + calculate(:sum, :bu_premium)
  end

  def self.di
    calculate(:sum, :di_premium) + calculate(:sum, :ml_premium)
  end

  def self.ltc
    calculate(:sum, :lc_premium)
  end

  def self.overall_performance
    life + di + ltc
  end

  def self.by_month
    (1..12).inject({}) do |hash, month|
      [:life, :ltc, :di].each do |category|
        hash[category] ||= []
        hash[category] << month(month).send(category)
      end
      hash
    end
  end

  def self.yearly_report(year_num)
    (1..12).inject([]) do |chart_data, i|
      chart_data << Premium.year(year_num).month(i).calculate(:sum, :life_premium) + Premium.year(year_num).month(i).calculate(:sum, :lc_premium) + Premium.year(year_num).month(i).calculate(:sum, :di_premium)
      chart_data
    end
  end

  def self.thirty_day_report
    chart_data = []
    (0..30).each do |i|
      day = (Time.now - i.days).strftime("%Y/%m/%d")
      chart_data << Premium.date(day).calculate(:sum, :life_premium) + Premium.date(day).calculate(:sum, :lc_premium) + Premium.date(day).calculate(:sum, :di_premium)
    end
    return chart_data
  end

  def self.latest_year
  # TODO: Think about this:
    @latest_year ||= calculate(:max, :event_date).year
  end

  def self.latest_month(year=latest_year)
    calculate(:max, :event_date, :conditions=>['YEAR(event_date) = ?', year]).month rescue 1
  end

  def self.latest_entry_date
    calculate(:max, :event_date)
  end

  def self.years
    @years ||= Premium.find_by_sql('select distinct(YEAR(event_date)) as year from premiums').map(&:year).compact.sort
  end

  def self.months(year=latest_year)
    Premium.find_by_sql("select distinct(MONTH(event_date)) as month from premiums where YEAR(event_date) = '#{year}'").map{|pe| pe.month}.compact.sort
  end

  def to_hash
    self.hash = self.attributes.reject{|k,v| k == 'hash'}.sort.to_s.hash
  end

  def life_premium_total
    self.bu_premium +
    self.bt_premium +
    self.sl_premium +
    self.life_premium
  end


  def total_premium
    self.lc_premium +
    self.ml_premium +
    self.bu_premium +
    self.bt_premium +
    self.di_premium +
    self.sl_premium +
    self.life_premium
  end

  def import_key
    "#{self.guardian_num}-#{self.total_premium}-#{self.event_date}"
  end

  class << self

    def update_from_guardian(date = Date.today, back_thru = nil)
      if report_name = GuardianAgent.get_paid_for_report(date, back_thru)
        Rails.cache.clear
        import_paid_for_report(report_name)
        # preload the cache with the stuff we need for the dashboard
        total_top_premium_this_month = MonthlyPremiumSummary.this_month_amount
        total_top_premium_last_month = MonthlyPremiumSummary.last_month_amount
        total_top_premium_ytd        = MonthlyPremiumSummary.year_to_date_amount
        total_top_premium_last_ytd   = MonthlyPremiumSummary.last_year_to_date_amount
        total_top_life_this_month    = LifePremiumSummary.this_month_amount
        total_top_life_last_month    = LifePremiumSummary.last_month_amount
        total_top_life_ytd           = LifePremiumSummary.year_to_date_amount
        total_top_life_last_ytd      = LifePremiumSummary.last_year_to_date_amount
        total_top_di_this_month      = DiPremiumSummary.this_month_amount
        total_top_di_last_month      = DiPremiumSummary.last_month_amount
        total_top_di_ytd             = DiPremiumSummary.year_to_date_amount
        total_top_di_last_ytd        = DiPremiumSummary.last_year_to_date_amount
        total_top_ltc_this_month     = LtcPremiumSummary.this_month_amount
        total_top_ltc_last_month     = LtcPremiumSummary.last_month_amount
        total_top_ltc_ytd            = LtcPremiumSummary.year_to_date_amount
        total_top_ltc_last_ytd       = LtcPremiumSummary.last_year_to_date_amount
        total_top_gdc_this_month     = MonthlyGdcSummary.this_month_amount
        total_top_gdc_last_month     = MonthlyGdcSummary.last_month_amount
        total_top_gdc_two_months_ago = MonthlyGdcSummary.two_months_ago_amount
        total_top_gdc_ytd            = MonthlyGdcSummary.year_to_date_amount
        total_top_gdc_last_ytd       = MonthlyGdcSummary.last_year_to_date_amount
        total_top_credits_this_month = MonthlyClubSummary.this_month_amount
        total_top_credits_last_month = MonthlyClubSummary.last_month_amount
        total_top_credits_two_months_ago = MonthlyClubSummary.two_months_ago_amount
        total_top_credits_ytd        = MonthlyClubSummary.year_to_date_amount
        total_top_credits_last_ytd   = MonthlyClubSummary.last_year_to_date_amount
        list_limit = Account.first.top_list
        top_premium_this_month       = MonthlyPremiumSummary.best_this_month(list_limit)
        top_premium_last_month       = MonthlyPremiumSummary.best_last_month(list_limit)
        top_premium_ytd              = MonthlyPremiumSummary.best_year_to_date(list_limit)
        top_premium_last_ytd         = MonthlyPremiumSummary.best_last_year(list_limit)
        top_life_this_month          = LifePremiumSummary.best_this_month(list_limit)
        top_life_last_month          = LifePremiumSummary.best_last_month(list_limit)
        top_life_ytd                 = LifePremiumSummary.best_year_to_date(list_limit)
        top_life_last_ytd            = LifePremiumSummary.best_last_year(list_limit)
        top_di_this_month            = DiPremiumSummary.best_this_month(list_limit)
        top_di_last_month            = DiPremiumSummary.best_last_month(list_limit)
        top_di_ytd                   = DiPremiumSummary.best_year_to_date(list_limit)
        top_di_last_ytd              = DiPremiumSummary.best_last_year(list_limit)
        top_ltc_this_month           = LtcPremiumSummary.best_this_month(list_limit)
        top_ltc_last_month           = LtcPremiumSummary.best_last_month(list_limit)
        top_ltc_ytd                  = LtcPremiumSummary.best_year_to_date(list_limit)
        top_ltc_last_ytd             = LtcPremiumSummary.best_last_year(list_limit)
        top_gdc_this_month           = MonthlyGdcSummary.best_this_month(list_limit)
        top_gdc_last_month           = MonthlyGdcSummary.best_last_month(list_limit)
        top_gdc_two_months_ago       = MonthlyGdcSummary.best(list_limit).two_months_ago
        top_gdc_ytd                  = MonthlyGdcSummary.best_year_to_date(list_limit)
        top_gdc_last_ytd             = MonthlyGdcSummary.best_last_year(list_limit)
        top_credits_this_month       = MonthlyClubSummary.best_this_month(list_limit)
        top_credits_last_month       = MonthlyClubSummary.best_last_month(list_limit)
        top_credits_two_months_ago   = MonthlyClubSummary.best(list_limit).two_months_ago
        top_credits_ytd              = MonthlyClubSummary.best_year_to_date(list_limit)
        top_credits_last_ytd         = MonthlyClubSummary.best_last_year(list_limit)
      end
      return report_name
    end

    def import_paid_for_report(report = nil)
      # TODO report = latest_report if report.blank?
      return false if report.blank?
      report = File.open(report).read if File.exists?(report)
      account = Account.first

      # grab all advisors once instead of a separate select for each new premium #
      advisors = {}
      account.users.find(:all).each do |user|
        advisors[user.guardian_num] = user
      end

      # grab all policies once instead of a separate select for each new premium #
      policy_list = {}
      Policy.find(:all).each do |policy|
        policy_list[policy.policy_num] = policy
      end

      # grab all distinct policy-total-date combos from database, to ensure no duplicate imports #
      payments = {}

      Premium.find(:all).each do |premium|
        payments[premium.import_key] = true
      end
      deb "payment import key length: #{payments.length}"
      csv = FasterCSV.parse(report)

      current_year_header = ["PRODID", "AGTNAME", "WRITCODE", "MGRCODE", "LOB", "STATDATE", "POLNUM", "BILLMODE", "INSLASTNAME", "INSFIRSTNAME", "POLTYPE", "AGTSHARE", "LIFEPREM", "SLPREM", "DIPREM", "BTPREM", "BUPREM", "MLPREM", "LCPREM", "\t"]
      # past_year_header    = ["PRODID", "AGTNAME", "WRITCODE", "MGRCODE", "LOB", "STATDATE", "POLNUM", "BILLMODE", "INSLASTNAME", "INSFIRSTNAME", "POLTYPE", "AGTSHARE", "LIFESHARE", "DISHARE", "SLSHARE", "BUSHARE", "BTSHARE", "MLSHARE", "LCSHARE", "LIFEPREM", "SLPREM", "DIPREM", "BTPREM", "BUPREM", "MLPREM", "LCPREM", "\t"]
      past_year_header    = ["PRODID", "AGTNAME", "WRITCODE", "MGRCODE", "LOB", "STATDATE", "POLNUM", "BILLMODE", "INSLASTNAME", "INSFIRSTNAME", "POLTYPE", "AGTSHARE", "LIFESHARE", "DISHARE", "SLSHARE", "BTSHARE", "BUSHARE", "MLSHARE", "LCSHARE", "LIFEPREM", "SLPREM", "DIPREM", "BTPREM", "BUPREM", "MLPREM", "LCPREM", "\t"]

      if csv.first == current_year_header || csv.first == past_year_header
        deb "matching format"
        @expected_headers = csv.first
      else
        deb "Import Format Error"
        raise ImportError, "The premiums CSV format has changed.  \nWe found #{csv.first.inspect}\n\nBut expected #{@expected_headers.inspect}"
      end

      csv.each do |row|
        deb "parsing row"
        # columns = [:PRODID, :AGTNAME, :WRITCODE, :MGRCODE, :LOB, :STATDATE, :POLNUM, :BILLMODE, :INSLASTNAME, :INSFIRSTNAME, :POLTYPE, :AGTSHARE, :LIFEPREM, :SLPREM, :DIPREM, :BTPREM, :BUPREM, :MLPREM, :LCPREM]
        hash = premium_csv_to_hash(row)
        next if hash.blank?
        # Skip header rows #
        next if hash[:PRODID] == 'PRODID'

        premium = Premium.new(  :lc_premium       => hash[:LCPREM],
                                :ml_premium       => hash[:MLPREM],
                                :bu_premium       => hash[:BUPREM],
                                :bt_premium       => hash[:BTPREM],
                                :di_premium       => hash[:DIPREM],
                                :sl_premium       => hash[:SLPREM],
                                :life_premium     => hash[:LIFEPREM],
                                :agent_share      => hash[:AGTSHARE],
                                :life_share       => hash[:LIFESHARE],
                                :di_share         => hash[:DISHARE],
                                :sl_share         => hash[:SLSHARE],
                                :bu_share         => hash[:BUSHARE],
                                :bt_share         => hash[:BTSHARE],
                                :ml_share         => hash[:MLSHARE],
                                :lc_share         => hash[:LCSHARE],
                                :guardian_num     => hash[:PRODID],
                                :billing_mode     => hash[:BILLMODE],
                                :line_of_business => hash[:LOB],
                                :mgr_code         => hash[:MGRCODE],
                                :writing_code     => hash[:WRITCODE],
                                :event_date       => hash[:STATDATE]
                              )

        # deb premium.guardian_num
        # deb hash

        # Skip blank or incomplete records #
        if premium.guardian_num.blank?
          deb "No Guardian Num, skipping record: #{hash}"
          next
        end

        # Skip entries that have already been imported #
        # next if payments.has_key?(premium.import_key)
        if payments.has_key?(premium.import_key)
          # deb premium.import_key
          deb "______((((((((((((( #{premium.import_key})))))))))))))______________"
          next
        end
        deb "Did not find premium by key, continuing ..."

        # Find advisor.  Create if needed. #
        advisor = advisors[premium.guardian_num]
        if advisor.blank?
          deb "Creating advisor..."
          advisor = account.users.build(:import_type => "premium", :guardian_name => hash[:AGTNAME], :guardian_num => premium.guardian_num)
          advisor.advisor = true
          advisor.active = true
          advisor.app_user = false
          advisor.save
          advisors[advisor.guardian_num] = advisor
        else
          deb "Found #{advisor.display_name}"
        end

        # Find policy.  Create if needed. #
        policy = policy_list[hash[:POLNUM]]
        if policy.blank?
          deb "Creating Policy: #{hash[:POLNUM]}"
          policy = Policy.create(
            :policy_num => hash[:POLNUM],
            :insured_last_name => hash[:INSLASTNAME],
            :insured_first_name => hash[:INSFIRSTNAME],
            :policy_type => hash[:POLTYPE],
            :billing_mode => hash[:BILLMODE],
            :line_of_business => hash[:LOB]
          )
          policy.advisors << advisor
          policy_list[policy.policy_num] = policy
        else
          deb "Found Policy: #{policy.policy_num}"
        end



        premium.advisor = advisor

        # TODO: Associate the premium to a Policy and/or SaleCase when I get the new relationship all figured out.
        #       In the meantime turn off
        # premium.sale_case = policy

        puts "Importing Premium for Advisor #{advisor.guardian_name}" unless $SUPPRESS_OUTPUT

        premium.save!
        # deb hash.inspect
        # deb [premium.life_premium.to_s, premium.di_premium.to_s, premium.lc_premium.to_s] * ', '
      end
    end

    def premium_csv_to_hash(csv)
      # columns = [:PRODID, :AGTNAME, :WRITCODE, :MGRCODE, :LOB, :STATDATE, :POLNUM, :BILLMODE, :INSLASTNAME, :INSFIRSTNAME, :POLTYPE, :AGTSHARE, :LIFESHARE, :DISHARE, :SLSHARE, :BUSHARE, :BTSHARE, :MLSHARE, :LCSHARE, :LIFEPREM, :SLPREM, :DIPREM, :BTPREM, :BUPREM, :MLPREM, :LCPREM ]
      return if csv.empty?
      columns = @expected_headers.map(&:to_sym)
      columns.inject({}) do |hash, header|
        return hash if header == "\t".to_sym # Skip last row of nothingness
        raise ImportError, "CSV header length and row header length do not match:\n #{columns.inspect}\n #{csv.inspect}" if columns.length != csv.length
        # p [csv[columns.index(header)], header]
        hash[header] = csv[columns.index(header)].strip rescue nil
        hash
      end
    end

    def rebuild_summaries_for_year(year = Time.now.year)
      Premium.year(year).find_each do |premium|
        puts "Building summaries for Premium id: #{premium.id} / Guardian Num: #{premium.guardian_num}\n"
        producer = premium.advisor
        if producer
          if producer.guardian_num != premium.guardian_num
            puts "xxxxxxxxxx Guardian Nums don't match for Premium id: #{premium.id} (#{producer.guardian_num} != #{premium.guardian_num})\n"
          end
          [MonthlyPremiumSummary, LifePremiumSummary, LtcPremiumSummary, DiPremiumSummary].each do |summary|
            summary.update_period(producer, premium.event_date.year, premium.event_date.month)
          end
        end
      end
    end

  end
end

# Premium.delete_all; Premium.import_paid_for_report("/srv/statusroom/current/reports/paidfor/paid-for-20080101-thru-20081231-184941.txt"); nil
