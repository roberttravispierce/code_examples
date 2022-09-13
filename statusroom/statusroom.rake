namespace :sr do
  desc "Send weekly to brokers"
  task :send_weekly_message => :environment do
    weekly_message = WeeklyMessage.current || begin
      account = if RAILS_ENV['ACCOUNT_ID']
                then Account.find(RAILS_ENV['ACCOUNT_ID'])
                else Account.first
                end
      WeeklyMessage.create(:account => account, :delivery_date => Date.today.beginning_of_week)
    end
    User.brokers.wants_notification.each { |broker| weekly_message.deliver(broker) }
  end

  desc "Send daily email to producer(s) with updated cases"
  task :send_daily_case_email, [:producer_id] => :environment do |t, args|

    dry_run = (ENV['DRY_RUN'] == 'true')
    if dry_run
      puts "Relax; this is just a dry run for the real thing."
    end

    run_time = DateTime.now
    @emails_sent = 0
    args.with_defaults(:producer_id => "")
    last_check = AppSettings.last_case_change_mail_at
    if args.producer_id == ""  # try all producers who want a daily email (default)
      if dry_run
        puts "User.producers.wants_daily_case_email.count is #{User.producers.wants_daily_case_email.count}"
        to_be_sent_email = 0
      end

      i = 0
      User.producers.wants_daily_case_email.has_email_address.each do |producer|
        changed_cases = producer.non_sst_changed_cases_since(last_check)
        activities = producer.non_sst_activities_since(last_check)
        $stdout.print "."
        $stdout.flush
        unless changed_cases.empty?
          i += 1
          if dry_run
            to_be_sent_email += 1
            puts "\n#{i}. Producer #{producer.full_name} (#{producer.id}) at #{producer.notification_email_addresses} has #{activities.size} case activities.\n"
            activities.each_with_index do |activity, idx|
              puts "\n#{idx+1}. Case ID: #{activity.sale_case_id} | Type: #{activity.trackable_type} - #{activity.change_type} | Description: #{activity.description} | By: #{activity.user_id} | At: #{activity.created_at}"
            end
          else
            puts "\nSending email to #{producer.full_name} (#{producer.id}) at #{producer.notification_email_addresses}\n"
            begin
              Mailer.deliver_daily_case_changes(producer, changed_cases, last_check)
              @emails_sent += 1
            rescue Exception => e
              puts "There was a problem with the addresses: #{e.message}"
            end
          end

          $stdout.print "+"
          $stdout.flush
        end
      end
      unless dry_run
        AppSettings.by_key("last_case_change_mail_at").first.update_attributes!(:value => run_time)
      end
    else # try the specific producer passed in
      if producer = User.find(args.producer_id.to_i)
        changed_cases = producer.changed_cases_since(last_check)
        if dry_run
          puts "Specific Producer #{producer.full_name} (#{producer.id}) has #{changed_cases.size} changed cases"
        else
          puts "\nSending email to #{producer.full_name} (#{producer.id}) at #{producer.notification_email_addresses}\n"
            begin
              Mailer.deliver_daily_case_changes(producer, changed_cases, last_check) unless changed_cases.empty?
              @emails_sent += 1
            rescue Exception => e
              puts "There was a problem with the addresses: #{e.message}"
            end
        end
      end
    end
    if dry_run
      puts "Total daily case update emails to be sent: #{to_be_sent_email}"
    else
      # Notify super_admin of successful run
      subject = "#{@emails_sent} Daily Case Emails Sent"
      message = "#{subject} at: #{run_time}"
      Mailer.deliver_notify_super_admin(subject, message)
    end
  end

  desc "Send email to producer(s) with issued/not paid cases"
  task :send_issued_not_paid_case_reminder_email, [:producer_id] => :environment do |t, args|
    args.with_defaults(:producer_id => "")
    if args.producer_id == ""  # try all producers who want a daily email (default)
      i = 0
      User.producers.wants_daily_case_email.has_email_address.each do |producer|
        inp_cases = producer.sale_cases.issued_not_paid.not_handled_by_sst
        $stdout.print "."
        $stdout.flush
        unless inp_cases.empty?
          i += 1
          puts "\nSending email to #{producer.full_name} (#{producer.id}) at #{producer.notification_email_addresses}\n"
          begin
            Mailer.deliver_inp_cases_reminder(producer, inp_cases)
          rescue Exception => e
            puts "There was a problem with the addresses: #{e.message}"
          end
          $stdout.print "+"
          $stdout.flush
        end
      end
    else # try the specific producer passed in
      if producer = User.find(args.producer_id.to_i)
        inp_cases = producer.sale_cases.issued_not_paid
        puts "\nSending email to #{producer.full_name} (#{producer.id}) at #{producer.notification_email_addresses}\n"
        begin
          Mailer.deliver_inp_cases_reminder(producer, inp_cases) unless inp_cases.empty?
        rescue Exception => e
          puts "There was a problem with the addresses: #{e.message}"
        end
      end
    end
  end

  desc "Fix up users without name attributes"
  task :fix_names => :environment do
    users = User.find(:all, :conditions => "last_name IS NULL OR last_name = ''")
    users.each do |user|
      raw_name = user.guardian_name.nil? ? user.name : user.guardian_name
      # we don't have any data on some admins
      puts "Processing User: #{user.id} with Guardian Num: #{user.guardian_num rescue ''}"
      if raw_name
        name_parts = raw_name.split(" ")
        case name_parts.size
        when 1
          first_name = ""
          last_name = name_parts[0].titleize
        when 2
          first_name = name_parts[1].titleize
          last_name = name_parts[0].titleize
        when 3
          first_name = name_parts[1..2].join(" ").titleize
          last_name = name_parts[0].titleize
        else
          first_name = ""
          last_name = raw_name.titleize
        end
        user.update_attributes(:last_name => last_name, :first_name => first_name)
        user.create_display_name
        user.save!
      end
    end
  end

  desc "Make current install safe for email blast testing"
  task :neuter_emails => :environment do
    keep_addresses = ["robert@c3mediagroup.com", "robert@advpractice.com"]
    User.all(:conditions => "email IS NOT NULL and email <> ''").each do |user|
       unless keep_addresses.include?(user.email)
         email_pieces = user.email.split('@')
         if email_pieces.size == 2
           user.update_attribute(:email, "#{email_pieces[0]}#{user.id}@example.com")
         else
           user.update_attribute(:email, "unknown#{user.id}@example.com")
         end
       end
    end
  end

  desc "Check guardian credentials"
  task :check_gol_credentials => :environment do
    unless GuardianAgent.test_log_into_guardian
      Account.first.killswitch!
    end
  end

  desc "Remove confidential info from footprints"
  task :scrub_footprints => :environment do
    i = 0
    FootprintDetail.all.each do |fpd|
      i += 1
      if fpd.params.has_key?("password")
        fpd.params["password"] = '[FILTERED]'
        fpd.save!
      end
      if i%100 == 0
        $stdout.print "."
        $stdout.flush
      end
    end
  end

  desc "Remove footprints for user"
  task :remove_footprints, [:user_id] => :environment do |t, args|
    unless args.user_id == ""
      if user = User.find(args.user_id.to_i)
        case_footprints = user.footprints.sale_cases
        case_footprints.each_with_index do |fp, idx|
          puts "#{idx+1}. Removing footprint #{fp.id} (#{fp.path}) for User: #{user.display_name}.\n"
          fp.footprint_details.each_with_index do |fpd, i|
            puts "     #{i+1}. Removing footprint detail id: #{fpd.id}.\n"
            fpd.destroy
          end
          fp.destroy
        end
      end
    end
  end

  desc "Transmogrify policies to sale_cases"
  task :policy_to_case => :environment do
    # Insert policy data into sale_case table
    ActiveRecord::Base.connection.execute("INSERT INTO sale_cases(policy_id, policy_number, insured_last_name, insured_first_name, policy_type, billing_mode, line_of_business, created_at, updated_at, advisor_id, cash, plan, mode, puapui, status, status_date, total_amount, total_annual_premium, primary_advisor, insurer, owner_last_name, owner_first_name) SELECT id, policy_num, insured_last_name, insured_first_name, policy_type, billing_mode, line_of_business, created_at, updated_at, advisor_id, cash, plan, mode, puapui, status, status_date, total_amount, total_annual_premium, primary_advisor, 'Guardian', insured_last_name, insured_first_name FROM policies")

    # Fix up foreign keys
    ActiveRecord::Base.connection.execute('UPDATE forecasts, sale_cases SET forecasts.sale_case_id = sale_cases.id WHERE forecasts.policy_id = sale_cases.policy_id')
    ActiveRecord::Base.connection.execute('UPDATE forecast_versions, sale_cases SET forecast_versions.sale_case_id = sale_cases.id WHERE forecast_versions.policy_id = sale_cases.policy_id')
    ActiveRecord::Base.connection.execute('UPDATE policy_shares, sale_cases SET policy_shares.sale_case_id = sale_cases.id WHERE policy_shares.policy_id = sale_cases.policy_id')
    ActiveRecord::Base.connection.execute('UPDATE policy_events, sale_cases SET policy_events.sale_case_id = sale_cases.id WHERE policy_events.policy_id = sale_cases.policy_id')
    ActiveRecord::Base.connection.execute('UPDATE premiums, sale_cases SET premiums.sale_case_id = sale_cases.id WHERE premiums.policy_id = sale_cases.policy_id')
    ActiveRecord::Base.connection.execute('UPDATE requirements, sale_cases SET requirements.sale_case_id = sale_cases.id WHERE requirements.policy_id = sale_cases.policy_id')

    # Fix up Messages
    ActiveRecord::Base.connection.execute("UPDATE messages, sale_cases SET messages.discussable_id = sale_cases.id, messages.discussable_type = 'SaleCase' WHERE messages.discussable_id = sale_cases.policy_id AND messages.discussable_type = 'Policy'")

    # Fix up Notes
    ActiveRecord::Base.connection.execute("UPDATE notes, sale_cases SET notes.notable_id = sale_cases.id, notes.notable_type = 'SaleCase' WHERE notes.notable_id = sale_cases.policy_id AND notes.notable_type = 'Policy'")

  end

  desc "Update initial sale case states from policies"
  task :policy_status_to_case => :environment do
    ActiveRecord::Base.connection.execute("UPDATE sale_cases, policies SET sale_cases.workflow_state = 'policy_issued' WHERE sale_cases.policy_id = policies.id AND policies.status = 'AAPD'")
    ActiveRecord::Base.connection.execute("UPDATE sale_cases, policies SET sale_cases.workflow_state = 'policy_issued' WHERE sale_cases.policy_id = policies.id AND policies.status = 'UAPP'")
    ActiveRecord::Base.connection.execute("UPDATE sale_cases, policies SET sale_cases.workflow_state = 'live' WHERE sale_cases.policy_id = policies.id AND policies.status = 'PAID'")
    ActiveRecord::Base.connection.execute("UPDATE sale_cases SET workflow_state = 'unknown' WHERE workflow_state IS NULL")
  end

  desc "Set NBU Coordinator IDS from Xylograph data *EXPERIMENTAL*"
  task :set_nbu_ids => :environment do
    ActiveRecord::Base.connection.execute("UPDATE sale_cases, xylograph_policies, xylograph_users
    SET sale_cases.nbu_coordinator_id = xylograph_users.user_id
    WHERE sale_cases.id = xylograph_policies.sale_case_id
    AND xylograph_policies.coordinator_id = xylograph_users.agent_id")
    ActiveRecord::Base.connection.execute("UPDATE users, sale_cases
    SET users.staff = 1, users.staff_function = 'NBC'
    WHERE users.id = sale_cases.nbu_coordinator_id")
  end

  desc "Give all sale cases an initial forecast"
  task :create_default_forecasts => :environment do
    SaleCase.all.each do |sale_case|
      sale_case.create_default_forecast
    end
  end

  desc "Set all attachments to not producer_viewable"
  task :set_attachments_to_not_producer_viewable => :environment do
    i = 1
    SaleCaseAttachment.all.each do |attachment|
      attachment.producer_viewable = false
      attachment.save
      i += 1
      $stdout.print "."
      $stdout.flush
      puts "\n#{i} Completed" if (i % 1000) == 0
    end
  end

  desc "Set all Initial Workflow States"
  task :set_initial_workflow_states => :environment do
    # Start with a clean slate
    ActiveRecord::Base.connection.execute("UPDATE sale_cases SET workflow_state = 'unknown'")
    # Set paid cases to inforce
    ActiveRecord::Base.connection.execute("UPDATE sale_cases SET workflow_state = 'inforce' WHERE status IN ('paid','bkpd')")
    # Set ntkn, decl cases
    ActiveRecord::Base.connection.execute("UPDATE sale_cases SET workflow_state = 'declined' WHERE status IN ('decl')")
    ActiveRecord::Base.connection.execute("UPDATE sale_cases SET workflow_state = 'not_taken_other' WHERE status IN ('ntkn')")
  end

  desc "Fix up missing case originations"
  task :fixup_originations => :environment do
    SaleCase.update_all("case_origination = 'W'", "insurer = 'Windsor'")
    SaleCase.update_all("case_origination = 'G'", "insurer = 'Guardian' and case_origination IS NULL")
  end

  desc "Clear stale sessions"
  task :clear_stale_sessions => :environment do
    sql = 'DELETE FROM sessions WHERE updated_at < DATE_SUB(NOW(), INTERVAL 2 WEEK);'
    ActiveRecord::Base.connection.execute(sql)
  end

  desc "Fix up SaleCase status_dates since launch"
  task :fix_case_status_dates => :environment do
    dry_run = (ENV['DRY_RUN'] == 'true')
    if dry_run
      puts "Relax; this is just a dry run for the real thing."
    end

    notes = Note.find(:all, :conditions => 'comment like "System: Case moved from%"')
    notes.each_with_index do |note, idx|
      sale_case = Requirement.find(note.notable_id).sale_case
      if sale_case
        if sale_case.status_date.blank? || (sale_case.status_date < note.created_at.to_date)
          if dry_run
            puts "#{idx+1}. Sale Case: #{sale_case.id} has a status_date of: #{sale_case.status_date}, which will be updated to #{note.created_at.to_date}\n\n"
          else
            sale_case.update_attribute(:status_date, note.created_at.to_date)
            puts "#{idx+1}. Sale Case: #{sale_case.id} has a status_date of: #{sale_case.status_date}, which is updated to #{note.created_at.to_date}\n\n"
          end
        else
          if dry_run
            puts "******** Exception ********** #{idx+1}. Sale Case: #{sale_case.id} has a status_date of: #{sale_case.status_date} and won't be updated by the note date of #{note.created_at.to_date}\n\n"
          end
        end
      end
    end
    # Ok, find recent cases that are still blank and set status_date to udpated_at
    puts "######################### Set empty status_dates to updated_at #########################"
    sale_cases = SaleCase.find(:all, :conditions => 'status_date is null and updated_at > "2010-11-02"')
    sale_cases.each_with_index do |sale_case, idx|
      sale_case.update_attribute(:status_date, sale_case.updated_at.to_date)
      puts "#{idx+1}. Sale Case: #{sale_case.id} status_date has been updated to: #{sale_case.status_date}\n\n"
    end
  end

  desc "one time fix for PA club summaries"
  task :fix_pa_clubsumm => :environment do
    club_reports = ClubReport.find(:all, :conditions => { :period_year => 2010, :period_month => 10 })
    club_reports.each do |club_report|
      if club_report.advisor
        club_report.summarize
      end
    end
  end

  desc "Clear club summaries and resummarize all club reports"
  task :resummarize_club_reports => :environment do
    Summary.find_each(:conditions=>{:type=>'LifeClubSummary'}).each{|s|s.destroy}
    Summary.find_each(:conditions=>{:type=>'DiClubSummary'}).each{|s|s.destroy}
    Summary.find_each(:conditions=>{:type=>'LtcClubSummary'}).each{|s|s.destroy}
    Summary.find_each(:conditions=>{:type=>'OtherClubSummary'}).each{|s|s.destroy}
    Summary.find_each(:conditions=>{:type=>'MonthlyClubSummary'}).each{|s|s.destroy}
    ClubReport.find_each do |club_report|
      if club_report.advisor
        puts "######################### Summarizing Club Report: #{club_report.period_month}/#{club_report.period_year} for Producer #{club_report.advisor.display_name} #########################"
        club_report.summarize
      end
    end
  end

  desc "Fix notes to reference proper sale_case"
  task :fix_notes_for_sale_case => :environment do
    i = 0
    count = Note.count

    puts "Adding proper sale_case_id to #{count} Notes"
    Note.record_timestamps=false
    Note.find_each do |note|
      i = i+1
      if i % 1000 == 0
        puts "Row #{i} of #{count} (%.2f %% complete)" % (100 * i.to_f / count)
      end
      if note.notable_type == "Requirement"
        notable_sale_case_id = note.notable.sale_case_id rescue nil
        note.update_attribute(:sale_case_id, notable_sale_case_id)
      end
    end
    Note.record_timestamps=true
  end

  # A few strange situations from the large data imports
  desc "Show invalid users"
  task :show_invalid_users => :environment do
    i = 0
    count = User.count
    User.find_each do |user|
      i = i+1
      if i % 1000 == 0
        puts "#{i} of #{count} users checked (%.2f %% complete)" % (100 * i.to_f / count)
      end
      if user.invalid?
        puts "Invalid User: #{user.id} - #{user.display}"
      end
    end
  end

end
