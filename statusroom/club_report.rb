# See "doc/LICENSE" for the license governing this code.

# == Schema Information
#
# Table name: club_reports
#
#  id                          :integer(4)      not null, primary key
#  advisor_id                  :integer(4)
#  period_year                 :integer(4)
#  period_month                :integer(4)
#  life                        :decimal(10, 2)  default(0.0)
#  di                          :decimal(10, 2)  default(0.0)
#  ltc                         :decimal(10, 2)  default(0.0)
#  bonus                       :decimal(10, 2)  default(0.0)
#  group                       :decimal(10, 2)  default(0.0)
#  pal                         :decimal(10, 2)  default(0.0)
#  prop_va                     :decimal(10, 2)  default(0.0)
#  non_prop_va                 :decimal(10, 2)  default(0.0)
#  pension                     :decimal(10, 2)  default(0.0)
#  amf                         :decimal(10, 2)  default(0.0)
#  gtc                         :decimal(10, 2)  default(0.0)
#  ius                         :decimal(10, 2)  default(0.0)
#  qual_total_lifediltc        :decimal(10, 2)  default(0.0)
#  qual_total_other            :decimal(10, 2)  default(0.0)
#  qual_total                  :decimal(10, 2)  default(0.0)
#  benefits_total_lifediltc    :decimal(10, 2)  default(0.0)
#  benefits_total_other        :decimal(10, 2)  default(0.0)
#  benefits_total              :decimal(10, 2)  default(0.0)
#  created_at                  :datetime
#  updated_at                  :datetime
#  apr                         :string(255)
#  club                        :string(255)
#  wap                         :string(255)
#  medical_dental_contribution :string(255)
#  centurion                   :string(255)
#  praetorian                  :string(255)
#  mdrt                        :string(255)
#  nsaa                        :string(255)
#  nqa                         :string(255)
#  contract_type               :string(255)
#
# Indexes
#
#  index_club_reports_on_advisor_id  (advisor_id)
#

class ClubReport < ActiveRecord::Base
  require 'summary' # Need this as long as all the sub-classes of summary live in summary.rb.  We can break them out later.
  belongs_to :advisor, :class_name => "User"
  validates_uniqueness_of :period_month, :scope => [:period_year, :advisor_id]
  named_scope :year, lambda {|year| {:conditions => {:period_year => year}} }
  named_scope :month, lambda {|month| {:conditions => {:period_month => month}} }
  named_scope :for_fr, :conditions => 'club_reports.contract_type IN ("FR EXP", "FR INEXP")'

  def summarize
    deb "Summarizing Club Report #{id}"
    %w[life di ltc other monthly].each do |category|
      eval(<<-EOE
        @#{category}_month =   advisor.#{category}_club_summaries.year(period_year).month(period_month).first
        @#{category}_month ||= advisor.#{category}_club_summaries.build(:when => \"#{period_month}/1/#{period_year}\")
      EOE
      )

    end
    %w[life di ltc].each do |category|
      eval(<<-EOE
       @#{category}_month.amount = #{category} - (previous_report.#{category} rescue 0)
      EOE
      )
    end

    if period_month == 1
      @other_month.amount = qual_total_other
      @monthly_month.amount = qual_total
    else
      @other_month.amount = qual_total_other - previous_report.qual_total_other rescue 0
      @monthly_month.amount = qual_total - previous_report.qual_total rescue 0
    end

    [@life_month, @di_month, @ltc_month, @other_month, @monthly_month].map(&:save!)
  end

  REPORT_ATTRIBUTES = [:life, :di, :ltc, :bonus, :group, :pal, :prop_va, :non_prop_va, :pension, :amf, :gtc, :ius,
    :qual_total_lifediltc, :qual_total_other, :qual_total,
    :benefits_total_lifediltc, :benefits_total_other, :benefits_total, :apr, :club, :wap, :medical_dental_contribution,
    :centurion, :praetorian, :mdrt, :nsaa, :nqa ]

  REPORT_ATTRIBUTES.each do |att|
    eval(<<-METHOD
    def #{att}_this_month
      monthly_number = (#{att} - (previous_report.#{att} rescue 0))
      return monthly_number
    end
    METHOD
    )
  end

  def previous_report
    # TODO Consider using some SQL to speed this up
    @previous_report ||= advisor.club_reports.select{|r| r.period_year == period_year && r.period_month < period_month }.last
  end

  def previous_year
    @previous_year ||= advisor.club_reports.find(:first, :conditions => {:period_year => period_year-1, :period_month => period_month})
  end

  def self.numbers_guide
    return {
      'Life'                                  => :life,
      'Disability'                            => :di,
      'Long Term Care'                        => :ltc,
      'Bonus Credits'                         => :bonus,
      'Group (Guardian &amp; Joint Venture)'  => :group,
      'PAL'                                   => :pal,
      'PROP VA'                               => :prop_va,
      'NON PROP VA'                           => :non_prop_va,
      'Pension'                               => :pension,
      'AMF'                                   => :amf,
      'GTC'                                   => :gtc,
      'IUS'                                   => :ius,
      'qual_total_lifediltc'                  => :qual_total_lifediltc,
      'qual_total_other'                      => :qual_total_other,
      'qual_total'                            => :qual_total,
      'benefits_total_lifediltc'              => :benefits_total_lifediltc,
      'benefits_total_other'                  => :benefits_total_other,
      'benefits_total'                        => :benefits_total
    }
  end

  class << self

    def most_recent_month
      self.calculate(:max, :period_month, :conditions => {:period_year => Time.now.year})
    end

    def on_target(year=Time.now.year, month=most_recent_month)
      self.year(year).month(month).count(:conditions => {:contract_type => ['FR EXP', 'FR INEXP', 'SPEC BKR', 'FP'], :apr => ' ON TARGET'})
    end

    def not_on_target(year=Time.now.year, month=most_recent_month)
      self.year(year).month(month).count(:conditions => {:contract_type => ['FR EXP', 'FR INEXP', 'SPEC BKR', 'FP'], :apr => ' NOT ON TARGET'})
    end 

    def qualified(year=Time.now.year, month=most_recent_month)
      self.year(year).month(month).count(:conditions => {:contract_type => ['FR EXP', 'FR INEXP', 'SPEC BKR', 'FP'], :apr => ' QUALIFIED'})
    end

    def countable_advisors(year=Time.now.year, month=most_recent_month)
      self.qualified(year, month) + self.on_target(year, month) + self.not_on_target(year, month) rescue 0
    end

    def extract_data(data, extract, range, options = { :skip_adjustment => false })
      extracted  = data[extract][range].strip.gsub(',', '').gsub('-', '')
      polarity   = data[extract][range][-1..-1] # Get the last character which is the polarity
      if !options[:skip_adjustment] && data[extract][/Adjustment/] && adjustment = data[extract][/Adjustments(\s*([0-9]|,|\.)*.){2}/][/(.......\.\d\d).?$/]
        adjustment = "#{adjustment[-1..-1]}#{adjustment[0..-2].gsub(',','')}"
        return "#{eval("(#{polarity}#{extracted}) + (#{adjustment})")}"
      end
      return "#{polarity}#{extracted}"
    end
    private :extract_data

    def import_clubsumm_report(data)
      begin
      unless RAILS_ENV == 'development'
        Rails.cache.clear
      end
      account = Account.first
      month, day, year = data[/CLUBS AND AWARDS SUMMARY AS OF \d\d\/\d\d\/\d\d/][31..-1].split('/')
      month = month.to_i
      year  = year.to_i + 2000

      acct_dir             = account.account_directory_path
      report_dir           = "#{acct_dir}/#{year}"
      `mkdir #{report_dir}`  unless File.exist?(report_dir)

      month_string         = sprintf("%2.2d", month)
      prev_month_string    = sprintf("%2.2d", month-1)

      report_file          = "#{report_dir}/#{month_string}.txt"
      previous_report_file = "#{report_dir}/#{prev_month_string}.txt"

      File.open(report_file, 'w+') {|f| f.write(data) }

      if month != 1 && !File.exist?(previous_report_file)
        return false, "The previous report file was not found.  Please add the reports in sequential order by month."
      end

      advisors_in_report = []

      data.each('-'*131) do |agent_data|
        begin
          next unless agent_data.length >= 3350
          # Break up the data on space-dash-space boundaries
          # We want word characters and spaces in agent name and contract_type (contract_type can be "SPECIAL AGENT")
          # And in fact there's at least one case where guardian_num has a space in it, daft though that seems
          # .*$ at end allows for trailing spaces or windows line endings
          mask = /([\w &]*)\s+-\s+([\w ]*)\s+-\s+([\w ]*).*$/
          matches = mask.match(agent_data)
          # skip if no match - this is probably the totals stuff at the end of the report
          next if matches.nil?
          agent_name =  matches[1].strip
          guardian_num = matches[2].strip
          contract_type = matches[3].strip
          apr_raw = extract_data(agent_data, /APR: .{170}/m, 4..70, :skip_adjustment => true)
          apr_status = apr_raw.strip.downcase.gsub(" ","_")

          next if agent_name.blank?
          logger.info "+++++++++++  Starting find_by_guardian_num +++++++++++++"
          advisor = User.find_by_guardian_num(guardian_num)
          if advisor
            logger.info "+++++++++++  Completed find_by_guardian_num. Advisor is #{advisor.id} / #{advisor.guardian_name} - #{advisor.guardian_num} +++++++++++++"
            advisor.advisor = true
            advisor.contract_type = contract_type
            advisor.apr_status = apr_status

            # This is breaking sometimes here due to duplicate logins (shouldn't be happening but need to defend against)
            if advisor.invalid?
              logger.info "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"
              logger.info "!!!!!!!!!!!!! Invalide attributes for Advisor id: #{advisor.id} (#{advisor.guardian_name}) CAN'T SAVE/UPDATE RECORD. !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"
              logger.info "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n"
              # advisor.save!
            else
              advisor.save!
            end
          else
            logger.info "++++++++++++++++++++++++++++++++++++++++++++++\n"
            logger.info "No Advisor found for Agent Name: #{agent_name} with Guardian Num: #{guardian_num}. Will try to create...\n"
            advisor = account.users.build(:import_type => "club")
            advisor.active        = true
            advisor.advisor       = true
            advisor.app_user      = false
            advisor.guardian_num  = guardian_num
            advisor.guardian_name = agent_name
            advisor.contract_type = contract_type
            advisor.apr_status    = apr_status

            # Make sure login is unique
            rand_num_string = (rand * 100).to_i.to_s # 3 digit number string
            login = agent_name.downcase.gsub(" ", '_')
            login_taken = User.find_all_by_login(login)
            if login_taken
              advisor.login = agent_name.downcase.gsub(" ", '_') + "_" + guardian_num + "_" + rand_num_string
            else
              advisor.login = login
            end
            advisor.password      = advisor.password_confirmation = User.random_password
            advisor.email         = "#{advisor.login + rand_num_string}@not.set"
            advisor.save!
            logger.info "++++++++++++++++++++++++++++++++++++++++++++++\n"
            logger.info "Successfully saved new Advisor: #{advisor.login} / #{advisor.email}\n"

          end

          advisor_apr_status = advisor.apr_statuses.find_or_create_by_period_month_and_period_year(month, year)
          advisor_apr_status.update_attribute(:name, apr_status)
          advisors_in_report << advisor
          @advisor = advisor

          club_report = advisor.club_reports.find_by_period_month_and_period_year(month, year)
          club_report = advisor.club_reports.build(:period_month => month, :period_year => year) if club_report.blank?

          # First column
          club_report.life                       = extract_data(agent_data, /(LIFE \(excludes PAL, VUL\).{170})/m, 45..59)
          club_report.di                         = extract_data(agent_data, /(DI:.{170})/m, 45..59)
          club_report.ltc                        = extract_data(agent_data, /(LTC:.{170})/m, 45..59)
          club_report.bonus                      = extract_data(agent_data, /(BONUS CREDITS.{170})/m, 45..59)
          club_report.group                      = extract_data(agent_data, /(GROUP: \(GUARDIAN & JOINT VENTURE\).{170})/m, 45..59)
          club_report.pal                        = extract_data(agent_data, /PAL & VUL \(EQUITY BASED LIFE\).{170}/m, 41..55)
          club_report.prop_va                    = extract_data(agent_data, /PROP VA, MF.{170}/m, 41..55)
          club_report.non_prop_va                = extract_data(agent_data, /NON PROP VA, MF, VL.{170}/m, 41..55)
          club_report.pension                    = extract_data(agent_data, /GROUP PENSION 401\(k\):.{170}/m, 45..59)
          club_report.amf                        = extract_data(agent_data, /ASSET MANAGEMENT FEES:.{170}/m, 45..59)

          # NOTE:Guardian removed this GUARDIAN TRUST COMPANY line beginning with the 10/31/2011 data report
          # club_report.gtc                        = extract_data(agent_data, /GUARDIAN TRUST COMPANY:.{170}/m, 45..59)
          club_report.gtc                        = 0.0
          club_report.ius                        = extract_data(agent_data, /IUS:.{170}/m, 45..59)
          # Second column
          club_report.qual_total_lifediltc       = extract_data(agent_data, /Club Credits:  Life, DI, LTC.{38}/m,          54..71, :skip_adjustment => true)
          club_report.qual_total_other           = extract_data(agent_data, /Club Credits:  Other.{46}/m,                  54..71, :skip_adjustment => true)
          club_report.qual_total                 = extract_data(agent_data, /Club Credits: Total:.{46}/m,                  54..71, :skip_adjustment => true)
          club_report.benefits_total_lifediltc   = extract_data(agent_data, /Benefits Credits: Life DI LTC PAL VUL.{29}/m, 54..71, :skip_adjustment => true)
          club_report.benefits_total_other       = extract_data(agent_data, /Benefits Credits: Other Eligible.{34}/m,      54..71, :skip_adjustment => true)
          club_report.benefits_total             = extract_data(agent_data, /Benefits Credits: Total:.{42}/m,              54..71, :skip_adjustment => true)
          club_report.apr                        = extract_data(agent_data, /APR: .{170}/m, 4..70, :skip_adjustment => true)
          club_report.club                       = extract_data(agent_data, /CLUB:.{170}/m, 5..60, :skip_adjustment => true)
          club_report.wap                        = extract_data(agent_data, /WAP: .{170}/m, 4..60, :skip_adjustment => true)
          club_report.medical_dental_contribution= extract_data(agent_data, /Medical\/\Dental Contribution.{170}/m, 42..52, :skip_adjustment => true)
          club_report.centurion                  = extract_data(agent_data, /Centurion:.{170}/m, 10..70, :skip_adjustment => true)
          club_report.praetorian                 = extract_data(agent_data, /Praetorian:.{170}/m, 11..70, :skip_adjustment => true)
          club_report.mdrt                       = extract_data(agent_data, /MDRT:.{170}/m, 5..70, :skip_adjustment => true)
          club_report.nsaa                       = extract_data(agent_data, /NSAA:.{170}/m, 5..70, :skip_adjustment => true)
          club_report.nqa                        = extract_data(agent_data, /NQA: .{170}/m, 4..70, :skip_adjustment => true)
          club_report.contract_type              = contract_type
          # logger.debug "*******************************".red_on_yellow

          if club_report.save!
            logger.info "************************************************************\n"
            logger.info "Successfully imported ClubSumm for #{agent_name} - #{guardian_num}\n"
          else
            logger.info "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"
            logger.info "Error in importing ClubSumm for #{agent_name} - #{guardian_num}\n"
            logger.info "Agent Data: \n#{agent_data}"
          end

          club_report.summarize

        rescue => err
          puts err
          puts err.backtrace * "\n"
          raise err
          next
        end
      end

      # Set :contract_type => 'FMR' and :advisor => false for any advisor who don't appear in current report
      contracted_users = User.all(:conditions => "contract_type is not NULL && contract_type != 'FMR'")
      users_to_purge = contracted_users - advisors_in_report
      logger.info "#{contracted_users.size} contracted_users #{contracted_users.map(&:id).inspect}"
      logger.info "#{advisors_in_report.size} advisors_in_report #{advisors_in_report.map(&:id).inspect}"
      logger.info "#{users_to_purge.size} users_to_purge #{users_to_purge.map(&:id).inspect}"

      #  Turning this off for now - Dangerous with not enough protection if something goes wrong earlier in the process.

      # if users_to_purge.size > 0
      #         logger.info "The following advisors no longer appear in the clubsumm report and have been changed to broker status:"
      #         users_to_purge.each_with_index do |purged, i|
      #           logger.info "#{i+1}. #{purged.guardian_name} (#{purged.guardian_num}) - Former contract type: #{purged.contract_type}"
      #         end
      #         #  Temporarily turn off
      #         ids = users_to_purge.map(&:id).join(',')
      #         User.update_all("advisor = 0, contract_type = 'FMR', apr_status = 'not_found'", "id in (#{ids})")
      #       else
      #         logger.info "No users found that needed to have contract_type purged"
      #       end

      return true
      rescue => ex
         # raise ex
          err_message = "(((((((( )))))))) \n #{inspect} \n\n There was a problem importing this file:\n#{ex}\n#{'-'*100}\n\nAdvisor in Report: #{advisors_in_report}\n#{'-'*100}"
          logger.warn(err_message)
          return false
        end
    end

  end

end
