namespace :xylograph do
  # ------------------------------------------------------------------------------------------------------------------
  #
  # These are all CSV exports from the Xylograph SQL Server database:
  #   GSJ_AgentCodes.txt
  #   GSJ_Agents.txt
  #
  # Exports should use delimited format, Unicode, Column names in first data row, Text qualifier ", Row separator {LF}
  desc 'Import xylograph agent data'
  task :import_agents, [:agent_file, :agent_codes_file] => :environment do |t, args|
    args.with_defaults(:agent_file => "GSJ_Agents.txt", :agent_codes_file => "GSJ_AgentCodes.txt")

    puts "Importing Agents from #{args.agent_file} and Agent codes from #{args.agent_codes_file}"

    if XylographUser.count > 0
       puts "you appear to have already imported Xylograph users"
       return
     end

    agent_codes = FasterCSV.read(File.join(RAILS_ROOT, "xylograph_data", args.agent_codes_file))

    FasterCSV.foreach(File.join(RAILS_ROOT, "xylograph_data", args.agent_file), {:headers => true, :header_converters => :symbol}) do |row|
      # perf here will probably be hideous but with 4K rows I don't think we care
      guardian_num = nil
      user_id = nil
      puts row.inspect if ENV['DRY_RUN'] == 'true'
      $stdout.print "."
      $stdout.flush

      user_found = false

      unless ENV['DRY_RUN'] == 'true'

        # Try matching login
        #  Account for logins padded during previous import
        agent_id_from_csv = row[:agentid].ljust(3,'*')
        if user = User.find_by_login(agent_id_from_csv)
          user_id = user.id
          user_found = true
        end

        # First try to find by Guardian Num
        unless user_id
          agent_codes.each do |code|
            if code[1] == row[:agentid]
              guardian_num = code[2].upcase
              if user = User.find_by_guardian_num(guardian_num)
                user_id = user.id
                user_found = true
                break
              end
            end
          end
        end

        # Backup: match on email if we can't match on user id or login
        # This avoids trying to insert duplicate emails in the users table
        unless user_id
          if user = User.find_by_email(row[:email])
            user_id = user.id
            user_found = true
          end
        end

        # At this point we've correlated to a user if any. Now make the XylographUser.
        xylograph_user = XylographUser.create!(
          :agent_code => guardian_num,
          :user_id => user_id,
          :agent_id => row[:agentid],
          :password => row[:password],
          :password2 => row[:password2],
          :last_login => row[:lastlogIn],
          :total_hits => row[:totalhits],
          :title => row[:title],
          :first_name => row[:firstname],
          :last_name => row[:lastname],
          :designation => row[:designation],
          :company => row[:company],
          :address2 => row[:address2],
          :address1 => row[:address1],
          :city => row[:city],
          :state => row[:state],
          :zip => row[:zip],
          :mailing_address => row[:mailingaddress],
          :mailing_city => row[:mailingcity],
          :mailing_state => row[:mailingstate],
          :mailing_zip => row[:mailingzip],
          :mailing_instructions => row[:mailinginst],
          :voice => row[:voice],
          :voice_free => row[:voicefree],
          :fax => row[:fax],
          :mobile => row[:mobile],
          :email => row[:email],
          :status_email => row[:statusemail],
          :supervisor_id => row[:supervisorid],
          :supervisor_disid => row[:supervisordisid],
          :supervisor_ltcid => row[:supervisorltcid],
          :supervisor_lifeid => row[:supervisorlifeid],
          :correspondence => row[:correspondence],
          :broker_class => row[:brokerclass],
          :broker_class_temp => row[:brokerclasstemp],
          :software => row[:software],
          :access_type => row[:accesstype],
          :employee_supervisor => row[:employeesupervisor],
          :employee_case_manager => row[:employeecasemanager],
          :comments => row[:comments],
          :agent_date => row[:agentdate],
          :update_id => row[:updateid],
          :bio => row[:biog],
          :sort_order => row[:sortorder],
          :ca_license => row[:calicense],
          :diuw_guide => row[:diuwguide],
          :assistant => row[:assistant],
          :assistant_phone => row[:assistantphone],
          :ltc_licensed => row[:ltclicensed],
          :di_inner_circle => row[:diinnercircle],
          :willner_agent => row[:willneragent],
          :employee_sales_assistant => row[:employeesalesassistant],
          :employee_call_center => row[:employeesallcenter],
          :employee => row[:employee],
          :site_access => row[:siteaccess],
          :date_added => row[:dateadded],
          :special_mailing => row[:specialmailing],
          :ltc_licensed_date => row[:ltclicenseddate],
          :software_date => row[:softwaredate],
          :aml_exp_date => row[:amlexpdate],
          :ltc_exp_date => row[:ltcexpdate]
        )

        if user_found
          user = User.find(user_id)
          user.broker = true
          user.app_user = true
          if xylograph_user.email.length < 3
            user.email = xylograph_user.agent_id + "@notset.com" unless user.email
          else
            # Could be multiple in xylograph data. Just get first one.
            user.email = xylograph_user.email.split(',')[0] unless user.email
          end
          user.bio = xylograph_user.bio unless user.bio
          user.city = xylograph_user.city unless user.city
          user.designations = xylograph_user.designation unless user.designations
          user.first_name = xylograph_user.first_name unless user.first_name
          user.last_name = xylograph_user.last_name unless user.last_name
          user.license = xylograph_user.ca_license unless user.license
          user.state = xylograph_user.state unless user.state
          user.street = xylograph_user.address1 unless user.street
          user.street_2 = xylograph_user.address2 unless user.street_2
          user.zip = xylograph_user.zip unless user.zip
          user.title = xylograph_user.title
          user.company = xylograph_user.company
          user.mailing_street = xylograph_user.mailing_address
          user.mailing_city = xylograph_user.mailing_city
          user.mailing_state = xylograph_user.mailing_state
          user.mailing_zip = xylograph_user.mailing_zip
          user.mailing_instructions = xylograph_user.mailing_instructions
          user.phone_toll_free = xylograph_user.voice_free
          user.phone_work = xylograph_user.voice
          user.phone_mobile = xylograph_user.mobile

          # Set notification_email from status_email, but filter out obvious bad ones
          if ['noemail@noemail.com', 'noemail@norcalbrokerage.com', 'noemail@glic.com', 'xxx.com' ].include? xylograph_user.status_email
            user.notification_email = ''
          else
            user.notification_email = xylograph_user.status_email
          end

          user.assistant = xylograph_user.assistant
          user.assistant_phone = xylograph_user.assistant_phone
          user.agent_identifier = xylograph_user.agent_id
          user.guardian_num = xylograph_user.agent_code unless user.guardian_num
          unless user.login
            if xylograph_user.agent_id.length < 3
              puts
              puts "Padding XylographUser agent_id #{xylograph_user.agent_id} to User login #{xylograph_user.agent_id.ljust(3,'*')}"
            end
            # Pad login to 3 characters with * if necessary
            user.login = xylograph_user.agent_id.ljust(3,'*')
            user.password = xylograph_user.password
            user.password_confirmation = xylograph_user.password
          end
          if user.save
            # puts "Updated SaleCase User #{user.id} - #{user.display_name} from XylographUser #{xylograph_user.agent_id}"
          else
            puts
            puts "Unable to update User for XylographUser #{xylograph_user.agent_id} (But found SaleCase User #{user.id} - #{user.display_name})"
            puts user.errors.full_messages.inspect
          end
        else # No matching sale_case found
          user = User.new
          user.account_id = 1
          user.broker = true
          user.app_user = true
          user.email = xylograph_user.email
          user.bio = xylograph_user.bio
          user.city = xylograph_user.city
          user.designations = xylograph_user.designation
          user.first_name = xylograph_user.first_name
          user.last_name = xylograph_user.last_name
          user.license = xylograph_user.ca_license
          user.state = xylograph_user.state
          user.street = xylograph_user.address1
          user.street_2 = xylograph_user.address2
          user.zip = xylograph_user.zip
          user.title = xylograph_user.title
          user.company = xylograph_user.company
          user.mailing_street = xylograph_user.mailing_address
          user.mailing_city = xylograph_user.mailing_city
          user.mailing_state = xylograph_user.mailing_state
          user.mailing_zip = xylograph_user.mailing_zip
          user.mailing_instructions = xylograph_user.mailing_instructions
          user.phone_toll_free = xylograph_user.voice_free
          user.phone_work = xylograph_user.voice
          user.phone_mobile = xylograph_user.mobile

          # Set notification_email from status_email, but filter out obvious bad ones
          if ['noemail@noemail.com', 'noemail@norcalbrokerage.com', 'noemail@glic.com', 'xxx.com' ].include? xylograph_user.status_email
            user.notification_email = ''
          else
            user.notification_email = xylograph_user.status_email
          end

          user.assistant = xylograph_user.assistant
          user.assistant_phone = xylograph_user.assistant_phone
          user.agent_identifier = xylograph_user.agent_id
          user.guardian_num = xylograph_user.agent_code unless user.guardian_num
          if xylograph_user.agent_id.length < 3
            puts
            puts "Padding XylographUser agent_id #{xylograph_user.agent_id} to User login #{xylograph_user.agent_id.ljust(3,'*')}"
          end
          user.login = xylograph_user.agent_id.ljust(3,'*')
          user.password = xylograph_user.password
          user.password_confirmation = xylograph_user.password
          if user.save
            xylograph_user.update_attribute(:user_id, user.id)
          else
            puts
            puts "Unable to create User for XylographUser #{xylograph_user.agent_id}"
            puts user.errors.full_messages.inspect
          end
        end
      end
    end # FasterCSV foreach on agents
  end

  # ------------------------------------------------------------------------------------------------------------------
  # Assumes all necessary source files are in /xylograph_data
  # These are all CSV exports from the Xylograph SQL Server database:
  #   GSJ_AgentCodes.txt
  #
  # Exports should use delimited format, Unicode, Column names in first data row, Text qualifier ", Row separator {LF}
  desc 'Populate User agent_codes from xylograph AgentCode data'
  task :populate_agent_codes, [:agent_codes_file] => :environment do |t, args|
    args.with_defaults(:agent_codes_file => "GSJ_AgentCodes.txt")

    puts "Populating User.agent_codes with Agent codes from #{args.agent_codes_file}"

    dry_run = (ENV['DRY_RUN'] == 'true')

    verbose = false

    if dry_run
      verbose = true
      puts "I could really use a SO-da"
    else
      puts "Oh NOEZ! This isn't a dry run. He's really gonna do it!"
      sleep 3
      if User.count(:conditions => 'length(agent_codes) > 0') > 0
        puts "You appear to already have some agent_codes in place. Running this import again will overwrite them."
        overwrite_codes = ask('Do you want to continue? (Y/N)')
        return unless overwrite_codes = "Y"
      end
    end

    codez = {}

    FasterCSV.foreach(File.join(RAILS_ROOT, "xylograph_data", args.agent_codes_file), {:headers => true, :header_converters => :symbol}) do |row|

      if dry_run
        puts row.inspect
      else
        $stdout.print "."
        $stdout.flush
      end

      agent_id = row[1]
      agent_code = row[2]
      # If we've never seen this agent_id, make an entry for him in the hash
      unless codez[agent_id]
        puts "Ooh, new one!  MAKING RECORD FOR #{agent_id}" if verbose
        codez[agent_id] = []
      else
        puts "YAWN!  Already knew about #{agent_id} (#{codez[agent_id].join(',')})" if verbose
      end
      # Now add this agent_code onto this agent's array of agent_codes
      codez[agent_id] << agent_code.upcase

    end # FasterCSV foreach on agent_codes

    codez.each do |agent_id, agent_codes|
      unless user = User.find_by_agent_identifier(agent_id)
        puts "Could not find a user with agent_identifier == '#{agent_id}'. Skipping..."
        next
      end

      if dry_run
        puts "For agent #{agent_id}, update_attribute(:agent_codes, #{agent_codes.join(', ')})"
        next
      else
        user.update_attribute(:agent_codes, agent_codes.join(','))
      end

    end
  end

  # ------------------------------------------------------------------------------------------------------------------
  # Assumes all necessary source files are in /xylograph_data
  # These are all CSV exports from the Xylograph SQL Server database:
  #   GSJ_Policies.txt
  #
  # Exports should use delimited format, Unicode, Column names in first data row, Text qualifier ", Row separator {LF}
  desc 'Import xylograph policy data'
  task :import_policies, [:infile] => :environment do |t, args|
    args.with_defaults(:infile => "GSJ_Policies.txt")
    infile = args.infile

    puts "Importing Policies from #{infile}"

    if XylographPolicy.count > 0
       puts "you appear to have already imported Xylograph policies"
       return
     end

    FasterCSV.foreach(File.join(RAILS_ROOT, "xylograph_data", infile), {:headers => true, :header_converters => :symbol}) do |row|
      if ENV['DRY_RUN'] == 'true'
        puts row.inspect
      else
        sale_case_id = nil
        new_case = false
        unless row[:policyautoid].nil?
          sale_case = SaleCase.find_by_xyl_policy_identifier(row[:policyautoid].strip)
          if sale_case
            sale_case_id = sale_case.id
            $stdout.print "."
          else
            sale_case = SaleCase.new
            new_case = true
            sale_case.case_origination = "I"
            $stdout.print "+"
          end
          $stdout.flush
        end

        # Save the raw data
        xylograph_policy = XylographPolicy.create!(
          :sale_case_id => sale_case_id,
          :policy_auto_id => row[:policyautoid],
          :policy_random_id => row[:policyrandomid],
          :agent_id => row[:agentid],
          :agent_id_cut => row[:agentidcut],
          :agent_id2 => row[:agentid2],
          :agent_id3 => row[:agentid3],
          :agent_id2_cut => row[:agentid2cut],
          :agent_id3_cut => row[:agentid3cut],
          :agent_id4_cut => row[:agentid4cut],
          :agent_id4 => row[:agentid4],
          :agent_id5 => row[:agentid5],
          :agent_id5_cut => row[:agentid5cut],
          :agent_id6 => row[:agentid6],
          :agent_id6_cut => row[:agentid6cut],
          :policy_dl => row[:policydl],
          :policy_number => row[:policynumber],
          :awaiting_uw_review => row[:awaitinguwreview],
          :client_first_name => row[:clientfirstname],
          :client_last_name => row[:clientlastname],
          :age => row[:age],
          :dob => row[:dob],
          :client_email => row[:clientemail],
          :client_website => row[:clientwebsite],
          :gender => row[:gender],
          :occupation => row[:occupation],
          :occupation_class => row[:occupationclass],
          :policy_type => row[:policytype],
          :benefit_amount => row[:benefitamount],
          :elimination_period => row[:eliminationperiod],
          :benefit_period => row[:benefitperiod],
          :date_received_agency => row[:datereceivedagency],
          :riders_options => row[:ridersoptions],
          :discounts => row[:discounts],
          :date_to_agent => row[:datetoagent],
          :date_delivery_req => row[:datedeliveryreq],
          :cash_collected => row[:cashcollected],
          :submit_date => row[:submitdate],
          :cash_collected_amount => row[:cashcollectedamount],
          :cash_returned => row[:cashreturned],
          :cash_returned_date => row[:cashreturneddate],
          :submit_premium => row[:submitpremium],
          :premium_mode => row[:premiummode],
          :status => row[:status],
          :status_agent_id => row[:statusagentid],
          :status_date => row[:statusdate],
          :status_premium => row[:statuspremium],
          :inforce_date => row[:inforcedate],
          :insurer => row[:insurer],
          :underwriter => row[:underwriter],
          :coordinator_id => row[:coordinatorid],
          :administrator_id => row[:administratorid],
          :supervisor_id => row[:supervisorid],
          :delivery_id => row[:deliveryid],
          :message_field => row[:messagefield],
          :fio => row[:fio],
          :policy_state => row[:policystate],
          :client_manager => row[:clientmanager],
          :status_details => row[:statusdetails]
        )

        user_id = nil
        user = nil
        xylograph_user = XylographUser.find_by_agent_id(xylograph_policy.agent_id)
        if xylograph_user
          user_id = xylograph_user.user_id
          user = User.find(user_id) if user_id
        end

        sale_case.xyl_policy_identifier = xylograph_policy.policy_auto_id

        sale_case.advisor_id = user_id unless sale_case.advisor_id
        sale_case.primary_advisor = user.name if (user)
        sale_case.line_of_business = xylograph_policy.policy_dl
        sale_case.policy_number = xylograph_policy.policy_number
        sale_case.owner_first_name = (xylograph_policy.client_first_name || 'Unknown')
        sale_case.insured_first_name = (xylograph_policy.client_first_name || 'Unknown')
        sale_case.owner_last_name = (xylograph_policy.client_last_name || 'Unknown')
        sale_case.insured_last_name = (xylograph_policy.client_last_name || 'Unknown')
        sale_case.insured_dob = xylograph_policy.dob
        sale_case.insured_email = xylograph_policy.client_email
        sale_case.insured_website = xylograph_policy.client_website
        sale_case.insured_gender = xylograph_policy.gender
        sale_case.insured_occupation = xylograph_policy.occupation
        sale_case.insured_occupation_class = xylograph_policy.occupation_class
        sale_case.product_type = xylograph_policy.policy_type
        case xylograph_policy.policy_dl
        when 'Life'
          sale_case.policy_type = 'Life'
        when 'Disability'
          sale_case.policy_type = 'DI'
        when 'LTC'
          sale_case.policy_type = 'LTC'
         when 'Annuity'
          sale_case.policy_type = 'Life'
        end
        sale_case.total_amount = xylograph_policy.benefit_amount
        sale_case.cash_collected = xylograph_policy.cash_collected_amount
        sale_case.total_annual_premium = xylograph_policy.submit_premium
        sale_case.total_annual_premium_issued = xylograph_policy.status_premium
        sale_case.us_state = xylograph_policy.policy_state
        sale_case.premium_mode = xylograph_policy.premium_mode
        sale_case.billing_mode = xylograph_policy.premium_mode
        sale_case.special_request = xylograph_policy.message_field
        sale_case.cash_collected = (xylograph_policy.cash_collected == 'Y')
        sale_case.cash_returned = (xylograph_policy.cash_returned == 'Y')
        sale_case.cash_amount = xylograph_policy.cash_collected_amount
        sale_case.rider_fio = (xylograph_policy.fio == 'Y')
        sale_case.benefit_period = xylograph_policy.benefit_period
        sale_case.benefit_elim_period = xylograph_policy.elimination_period
        sale_case.submit_to_glic_date = xylograph_policy.submit_date
        sale_case.riders_options = xylograph_policy.riders_options
        sale_case.discounts = xylograph_policy.discounts
        nbu_staff_mappings = {  'ani007'      => 291,
                                'serventeka'  => 304,
                                'thomasonma'  => 308,
                                'Smithka'     => 4451,
                                'Arias007'    => 7021,
                                'brownde'     => 10981,
                                'CarvajalEd'  => 12381,
                                'holmesje'    => 23871,
                                'jjones'      => 49141,
                                'Mats007'     => 31301,
                                'NelsonAr'    => 34151,
                                'poe007'      => 37141,
                                'ram007'      => 37751,
                                'WitteTo'     => 47981,
                                'Hriss007'    => 284,
                                'Mooreken'    => 33301,
                                'cortezsh'    => 14631,
                                'Avilaju'     => 7401,
                                'SmithDe'     => 42361,
                                'segovianode' => 41111
                              }
        sale_case.nbu_coordinator_id = nbu_staff_mappings[xylograph_policy.coordinator_id] || nil
        sale_case.nbu_processor_id = nbu_staff_mappings[xylograph_policy.delivery_id] || nil

        sale_case.workflow_state = {'Approved' => 'approved',
                            'Closed/Incomplete' => 'closed_incomplete',
                            'Change' => 'inforce',
                            'Declined' => 'declined',
                            'Gone To Issue' => 'gone_to_issue',
                            'Hold' => 'application_hold',
                            'Issued/Not Paid' => 'issued_not_paid',
                            'Paid' => 'paid',
                            'Pending' => 'pending',
                            'Postponed' => 'postponed',
                            'Refused/NTO' => 'not_taken_other',
                            'Reinsurance' => 'to_reinsurance',
                            'Reissue' => 'reissue_requested',
                            'Tentative Offer' => 'tentative_offer',
                            }[xylograph_policy.status] || 'unknown'

        sale_case.status_date = xylograph_policy.status_date
        sale_case.created_at = xylograph_policy.date_received_agency || Time.now
        sale_case.updated_at = xylograph_policy.status_date || Time.now
        sale_case.insurer = xylograph_policy.insurer
        sale_case.plan = xylograph_policy.policy_type

        if xylograph_policy.underwriter
          name_parts = xylograph_policy.underwriter.split
          first_name = name_parts[0]
          last_name = name_parts[-1]
          underwriter = GuardianPerson.find_by_first_name_and_last_name(first_name, last_name)
          if underwriter
            sale_case.glic_underwriter = underwriter
          end
        end

        if sale_case.save
          puts "Saved case: #{sale_case.id}"

          # Now create the policy shares
          if new_case
            if xylograph_policy.agent_id && xylograph_policy.agent_id_cut
              user = User.find_by_agent_identifier(xylograph_policy.agent_id)
              if user
                SaleCaseShare.create(:producer_id => user.id, :sale_case_id => sale_case.id, :share => (xylograph_policy.agent_id_cut.to_i))
              end
            end

            if xylograph_policy.agent_id2 && xylograph_policy.agent_id2_cut
              user = User.find_by_agent_identifier(xylograph_policy.agent_id2)
              if user
                SaleCaseShare.create(:producer_id => user.id, :sale_case_id => sale_case.id, :share => (xylograph_policy.agent_id2_cut.to_i))
              end
            end

            if xylograph_policy.agent_id3 && xylograph_policy.agent_id3_cut
              user = User.find_by_agent_identifier(xylograph_policy.agent_id3)
              if user
                SaleCaseShare.create(:producer_id => user.id, :sale_case_id => sale_case.id, :share => (xylograph_policy.agent_id3_cut.to_i))
              end
            end

            if xylograph_policy.agent_id4 && xylograph_policy.agent_id4_cut
              user = User.find_by_agent_identifier(xylograph_policy.agent_id4)
              if user
                SaleCaseShare.create(:producer_id => user.id, :sale_case_id => sale_case.id, :share => (xylograph_policy.agent_id4_cut.to_i))
              end
            end

            if xylograph_policy.agent_id5 && xylograph_policy.agent_id5_cut
              user = User.find_by_agent_identifier(xylograph_policy.agent_id5)
              if user
                SaleCaseShare.create(:producer_id => user.id, :sale_case_id => sale_case.id, :share => (xylograph_policy.agent_id5_cut.to_i))
              end
            end

            if xylograph_policy.agent_id6 && xylograph_policy.agent_id6_cut
              user = User.find_by_agent_identifier(xylograph_policy.agent_id6)
              if user
                SaleCaseShare.create(:producer_id => user.id, :sale_case_id => sale_case.id, :share => (xylograph_policy.agent_id6_cut.to_i))
              end
            end
          end

          # Create case note from status detail
          unless xylograph_policy.status_details.empty?
            requirement = sale_case.requirements.case_notes.first
            status_note = Note.new(:notable_type => 'Requirement', :notable_id => requirement.id, :access_level => 'staff', :comment => xylograph_policy.status_details)
            if status_note.save
              $stdout.print "(+ Status Note for #{xylograph_policy.policy_auto_id})"
              $stdout.flush
            else
              puts "Unable to save note:"
              puts status_note.errors.full_messages.inspect
              puts status_note.to_yaml
            end
          end

        else # unable to save
          puts "Unable to save:"
          puts sale_case.errors.full_messages.inspect
          puts sale_case.to_yaml
          puts xylograph_policy.to_yaml
        end
      end
    end # FasterCSV foreach on policies
  end

  # ------------------------------------------------------------------------------------------------------------------
  # Assumes all necessary source files are in /xylograph_data
  # These are all CSV exports from the Xylograph SQL Server database:
  #   GSJ_Proposals.txt
  #
  # Exports should use delimited format, Unicode, Column names in first data row, Text qualifier ", Row separator {LF}
  desc 'Import xylograph proposal data'
  task :import_proposals, [:infile] => :environment do |t, args|
    args.with_defaults(:infile => "GSJ_Proposals.txt")
    infile = args.infile

    puts "Importing Proposals from #{infile}"

    dry_run = (ENV['DRY_RUN'] == 'true')

    verbose = false

    if dry_run
      verbose = true
      puts "I could really use a SO-da"
    else
      puts "Oh NOEZ! This isn't a dry run. He's really gonna do it!"
      sleep 5

      if XylographProposal.count > 0
        puts "You appear to have already imported Xylograph proposals.\n"
        clear_table = ask('Do you want to clear the table and continue? (Y/N)')
        if clear_table = "Y"
          XylographProposal.delete_all
        else
          return
        end
      end
    end

    # We have to use proposalrandomid for these, as (1) the proposalautoid might conflict with
    # previous Policy imports to SaleCases.  Since Proposals and Policies were two completely
    # different DBs in the original system, there's no reason for the IDs not to overlap, so
    # that's bad.
    #
    # Also, these Proposals are associated with their corresponding Notes and Attachments by
    # the RandomId, which is usually blank in the older imports we've done, like Policies.

    FasterCSV.foreach(File.join(RAILS_ROOT, "xylograph_data", infile), {:headers => true, :header_converters => :symbol}) do |row|
      if dry_run || verbose
        puts "\n"
        puts "-" * 80
        puts "\n"
        puts row.inspect
      end

      # Save the raw data
      xylograph_proposal = XylographProposal.create!(
        :proposal_auto_id => row[:proposalautoid],   # Remember we're not using this for much now
        :proposal_random_id => row[:proposalrandomid],
        :agent_id => row[:agentid],
        :quote_run_by => row[:quoterunby],
        :proposal_dl => row[:proposaldl],
        :proposal_status => row[:proposalstatus],
        :client_name => row[:clientname],
        :proposal_date => row[:proposaldate],
        :reminder_date => row[:reminderdate],
        :origination_info => row[:originationinfo],
        :message_field => row[:messagefield],
        :supervisor_id => row[:supervisorid],
        :last_email_date => row[:lastemaildate],
        :proposal_filename => row[:proposalfilename],
        :upload_date => row[:uploaddate],
        :first_mail_sent => row[:firstmailsent],
        :second_mail_sent => row[:secondmailsent],
        :policy_data => row[:policydata],
        :status_agent_id => row[:statusagentid],
        :status_date => row[:statusdate],
        :app => row[:app],
        :followup => row[:followup],
        :territory_id => row[:territoryid]
      )

      sale_case_id = nil
      new_case = false
      if xylograph_proposal.proposal_random_id.strip.empty?
        puts "Cannot import Xylograph Proposal without a RandomID field to map it with. Skipping this record:"
        puts "#" * 70
        puts row.inspect
        puts "#" * 70
        next
      end

      sale_case = SaleCase.find_by_xyl_policy_identifier(xylograph_proposal.proposal_random_id.strip)
      if sale_case
        sale_case_id = sale_case.id
        $stdout.print "."
      else
        sale_case = SaleCase.new
        new_case = true
        sale_case.case_origination = "I"
        if xylograph_proposal.proposal_date >= 1.days.ago.to_date
          sale_case.workflow_state = 'info_requested'
        else
          sale_case.workflow_state = 'call_center_closed'
        end

        $stdout.print "+"
      end
      $stdout.flush

      user = find_user_for_xylograph_id(xylograph_proposal.agent_id)
      puts "Found user: #{user.inspect}" unless user.nil? || !verbose

      sale_case.xyl_policy_identifier = xylograph_proposal.proposal_random_id

      case xylograph_proposal.proposal_dl   # TODO: refactor this
      when 'Life'
        sale_case.policy_type = 'Life'
      when 'Disability'
        sale_case.policy_type = 'DI'
      when 'LTC'
        sale_case.policy_type = 'LTC'
      when 'Info'
        sale_case.policy_type = 'Info'
      else
        sale_case.policy_type = 'Info'
      end

      if quote_user = find_user_for_xylograph_id(xylograph_proposal.quote_run_by)
        sale_case.callctr_processor_id = quote_user.id
      else
        puts "COULD NOT FIND A USER FOR #{xylograph_proposal.quote_run_by}" if verbose
      end

      sale_case.insured_last_name = xylograph_proposal.client_name
      # We don't want to bother parsing the client_name, but SaleCase requires this not be blank
      sale_case.insured_first_name = "-imported-"
      sale_case.created_at = xylograph_proposal.proposal_date || Time.now
      sale_case.updated_at = xylograph_proposal.status_date || Time.now
      sale_case.request_source = xylograph_proposal.origination_info


      if new_case
        if agent_user = find_user_for_xylograph_id(xylograph_proposal.agent_id)
          puts "Agent User: #{agent_user}" if verbose
        else
          puts "COULD NOT FIND USER FOR #{xylograph_proposal.agent_id}" if verbose
        end
      end

      sale_case.request_info = [ "Policy Data: #{xylograph_proposal.policy_data}",
                                 "Message Field: #{xylograph_proposal.message_field}",
                                 "Status Agent: #{xylograph_proposal.status_agent_id}",
                                 "Status Date: #{xylograph_proposal.status_date}",
                                 "App: #{xylograph_proposal.app}",
                               ].join("\n")

      # Time to bail unless we're fo' realz
      if dry_run
        puts "Here's what we're saving:"
        puts "*" * 80
        puts "*" * 80
        puts "*" * 80
        puts sale_case.inspect
        puts "*" * 80
        puts "*" * 80
        puts "*" * 80
        next
      end

      if sale_case.save
        puts "Saved case: #{sale_case.id}"

        # Create case note from status detail

      else # unable to save
        puts "Unable to save:"
        puts "#" * 60
        puts sale_case.errors.full_messages.inspect
        puts sale_case.to_yaml
        puts "#" * 60
        puts xylograph_proposal.to_yaml
        puts "#" * 60
        puts "#" * 60
      end

      # Now create the policy shares
      if new_case
        if xylograph_proposal.agent_id
          if agent_user = User.find_by_agent_identifier(xylograph_proposal.agent_id)
            SaleCaseShare.create(:producer_id => agent_user.id, :sale_case_id => sale_case.id, :share => 100)
          else
            puts "WARNING: Could not find an agent_user for #{xylograph_proposal.agent_id} to produce SaleCaseShare"
          end
        end
      end

    end # FasterCSV foreach on proposals
  end

  # PROPOSAL NOTES -> NOTES ------------------------------------------------------------------------------------------------------------------
  # Assumes all necessary source files are in /xylograph_data
  # These are all CSV exports from the Xylograph SQL Server database:
  #   GSJ_ProposalNotes.txt
  #
  # Exports should use delimited format, Unicode, Column names in first data row, Text qualifier ", Row separator {LF}
  desc 'Import xylograph proposal notes data'
  task :import_proposal_notes, [:infile] => :environment do |t, args|
    args.with_defaults(:infile => "GSJ_ProposalNotes.txt")
    infile = args.infile

    puts "Importing ProposalNotes from #{infile}"

    dry_run = (ENV['DRY_RUN'] == 'true')

    unless dry_run
      puts "Oh NOEZ! This isn't a dry run. He's really gonna do it!"
      sleep 3

      if XylographProposalNote.count > 0
        puts "You appear to have already imported Xylograph Proposal Notes.\n"
        clear_table = ask('Do you want to clear the table and continue? (Y/N)')
        if clear_table = "Y"
          XylographProposalNote.delete_all
        else
          return
        end
      end
    end

    i = 1
    FasterCSV.foreach( File.join(RAILS_ROOT, "xylograph_data", infile),
                      { :headers => true, :header_converters => :symbol }
                     ) do |row|
      i += 1

      if dry_run
        puts "Row #{i}: #{row.inspect}"
        next
      else
        # exit
      end

      $stdout.print "."
      $stdout.flush
      puts "\nRow #{i}" if (i % 1000) == 0

      if row[:proposalrandomid].strip.empty?
        puts "Cannot import Xylograph Proposal Note without a RandomID field to map it with. Skipping this record:"
        puts "#" * 70
        puts row.inspect
        puts "#" * 70
        next
      end

      sale_case = SaleCase.find_by_xyl_policy_identifier(row[:proposalrandomid].strip)

      user = find_user_for_xylograph_id(row[:agentid])

      puts "Found #{user.id rescue 'ARG'} for User.id and #{sale_case.id rescue 'ARG2'} for SaleCase.id" if dry_run

      # If we can't match this imported record to a SaleCase, don't bother
      # making a Note for it (per Robert)
      unless sale_case
        puts "\nCannot import Xylograph Proposal Note without a matching SaleCase. Skipping this record:"
        puts "#" * 70
        puts row.inspect
        puts "#" * 70
        next
      end

      # Save the raw data
      xylograph_proposal_note = XylographProposalNote.create!(
        :sale_case_id => sale_case.id,
        :user_id => user.id,
        :chat_auto_id => row[:chatautoid],
        :policy_auto_id => row[:policyautoid],
        :message => row[:message],
        :proposal_random_id => row[:proposalrandomid],
        :agent_id => row[:agentid],
        :chat_type => row[:chattype],
        :chat_date => row[:chatdate],
        :to_email => row[:toemail],
        :cc_email => row[:ccemail],
        :bcc_email => row[:bccemail],
        :chat => row[:chat],
        :status_auto_id => row[:statusautoid],
        :status_agent_id => row[:statusagentid],
        :status_date => row[:statusdate],
        :private => row[:private],
        :include => row[:include],
        :chat_status_flag => row[:chatstatusflag],
        :remind_date => row[:reminddate]
      )

      # SaleCase objects should have one Requirement attached with a description
      # of "Case Notes".  It could theoretically have more than one, though it
      # doesn't appear to need it.  Anyway, we're going to need to attach any
      # notes we create here to that one Requirement, so we need to make sure
      # it has one, because some may have slipped through during some import
      # process and not had a "Case Notes" Requirement attached.

      sale_case.create_initial_case_requirement

      requirement = sale_case.requirements.case_notes.first
      if requirement.nil?
        puts "ERROR: Couldn't find a 'Case Notes' requirement for SaleCase ##{sale_case.id}. Note not created."
        next
      end

      # Now build a Note from it
      note = Note.find_or_initialize_by_original_id_and_original_type(xylograph_proposal_note.chat_auto_id, 'XylographProposalNote')

      note.user_id = user.id

      note.comment = "Imported: " + xylograph_proposal_note.chat
      # We only care about the ones we can connect to a SaleCase. But we're going
      # to treat them all as SaleCase-connected ones.  We'll actually connect it
      # to the SaleCase's special "Case Notes" Requirement, since that's where all
      # the notes attach (acts_as_notable) for a SaleCase.

      note.notable_type = 'Requirement'
      note.notable_id = requirement.id

      note.created_at = xylograph_proposal_note.chat_date
      note.access_level = 'staff'

      if ! note.save
         puts "unable to save:"
         puts note.errors.full_messages.inspect
         puts note.to_yaml
      end

    end # FasterCSV foreach on proposalnotes
  end

  # PROPOSAL_ATTACHMENTS -> ATTACHMENTS ------------------------------------------------------------------------------------------------------------------
  # Assumes all necessary source files are in /xylograph_data
  # These are all CSV exports from the Xylograph SQL Server database:
  #   GSJ_ProposalAttachments.txt
  #
  # Exports should use delimited format, Unicode, Column names in first data row, Text qualifier ", Row separator {LF}
  desc 'Import xylograph proposal attachments data'
  task :import_proposal_attachments, [:infile] => :environment do |t, args|
    args.with_defaults(:infile => "GSJ_ProposalAttachments.txt")
    infile = args.infile

    puts "Importing ProposalAttachments from #{infile}"

    dry_run = (ENV['DRY_RUN'] == 'true')

    unless dry_run
      if XylographProposalAttachment.count > 0
        puts "You appear to have already imported Xylograph Proposal Attachments"
        clear_table = ask('Do you want to clear the table and continue? (Y/N)')
        if clear_table = "Y"
          XylographProposalAttachment.delete_all
        else
          return
        end
      end

      puts "Oh NOEZ! This isn't a dry run. He's really gonna do it!"
      sleep 5
    end

    i = 1
    FasterCSV.foreach( File.join(RAILS_ROOT, "xylograph_data", infile),
                      { :headers => true, :header_converters => :symbol }
                     ) do |row|
      i += 1

      if dry_run
        puts "Row #{i}: #{row.inspect}"
        next
      else
        # exit
      end

      $stdout.print "."
      $stdout.flush
      puts "\nRow #{i}" if (i % 1000) == 0

      if row[:proposalrandomid].strip.empty?
        puts "Cannot import Xylograph Proposal Attachment without a RandomID field to map it with. Skipping this record:"
        puts "#" * 70
        puts row.inspect
        puts "#" * 70
        next
      end

      sale_case = SaleCase.find_by_xyl_policy_identifier(row[:proposalrandomid].strip)

      puts "Found #{sale_case.id} for SaleCase.id" if dry_run

      # If we can't match this imported record to a SaleCase, don't bother
      # making a Note for it (per Robert)
      unless sale_case
        puts "\nCannot import Xylograph Proposal Attachment without a matching SaleCase. Skipping this record:"
        puts "#" * 70
        puts row.inspect
        puts "#" * 70
        next
      end

      # Save the raw data
      xylograph_proposal_attachment = XylographProposalAttachment.create!(
        :sale_case_id => sale_case.id,
        :proposal_attachment_auto_id => row[:proposalattachmentautoid],
        :proposal_random_id => row[:proposalrandomid],
        :proposal_attachment_file_name => row[:proposalattachmentfilename],
        :proposal_attachment_label => row[:proposalattachmentlabel],
        :upload_date => row[:uploaddate]
      )

      # Now build a SaleCaseAttachment from it
      attachment = SaleCaseAttachment.find_or_initialize_by_original_id_and_original_type(row[:proposalattachmentautoid], 'XylographProposalAttachment')

      attachment.sale_case_id = sale_case.id

      attachment.attachment_file_name = xylograph_proposal_attachment.proposal_attachment_file_name
      attachment.description = "Imported: " + xylograph_proposal_attachment.proposal_attachment_label
      attachment.created_at = xylograph_proposal_attachment.upload_date
      attachment.producer_viewable = false # Private doesn't mean the same thing in old data so set to false to be safe
      attachment.attachment_content_type = "application/pdf"
      attachment.attachment_file_size = -1   # We have no idea, so let's make sure that's clear
      attachment.attached_by = nil

      if ! attachment.save
         puts "unable to save:"
         puts attachment.to_yaml
      end

    end # FasterCSV foreach on attachments
  end

# STATUS -> REQUIREMENTS ------------------------------------------------------------------------------------------------------------------
  # Assumes all necessary source files are in /xylograph_data
  # These are all CSV exports from the Xylograph SQL Server database:
  #   GSJ_Status.txt
  #
  # Exports should use delimited format, Unicode, Column names in first data row, Text qualifier ", Row separator {LF}
  desc 'Import xylograph status data'
  task :import_status, [:infile] => :environment do |t, args|
    args.with_defaults(:infile => "GSJ_Status.txt")
    infile = args.infile

    puts "Importing Statuses from #{infile}"

    dry_run = (ENV['DRY_RUN'] == 'true')

    if !dry_run && XylographStatus.count > 0
      puts "you appear to have already imported Xylograph statuses"
      return
    end

    unless dry_run
      puts "Oh NOEZ! This isn't a dry run. He's really gonna do it!"
      sleep 5
    end

    i = 1
    FasterCSV.foreach( File.join(RAILS_ROOT, "xylograph_data", infile),
                      { :headers => true, :header_converters => :symbol }
                     ) do |row|
      i += 1

      if dry_run
        puts "Row #{i}: #{row.inspect}"
        next
      else
        # exit
      end

      $stdout.print "."
      $stdout.flush
      puts "\nRow #{i}" if (i % 1000) == 0

      sale_case_id = nil

      unless row[:policyautoid].nil?
        # puts "Found a policy in row #{i-1}: #{row[:policyautoid]}"
        # xp = XylographPolicy.find_by_policy_auto_id(row[:policyautoid].strip)
        sale_case = SaleCase.find_by_xyl_policy_identifier(row[:policyautoid].strip)
        if sale_case
          sale_case_id = sale_case.id
          # if sc = xp.sale_case
          #   puts "Found the SaleCase: #{sc.policy_number} on #{sc.insured_first_name + ' ' + sc.insured_last_name}."
          # else
          #   puts "I found a Xylo Policy, but no SaleCase. :(  Here's the XyloPoli: #{xp.policy_number} on #{xp.client_first_name + ' ' + xp.client_last_name}."
          #   puts "The underwriter was #{xp.underwriter}, whatever that really means."
          # end
          # if agent = XylographUser.find_by_agent_id(row[:statusagentid])
          #   puts "Let me also add that Status agent is # #{agent.id}, a.k.a., #{agent.first_name + ' ' + agent.last_name}, but the REAL identity is user # #{agent.user.id} (or #{agent.user.display_name})"
          # end
        else
          puts "*" * 80
          puts "** I iz teh sad. No could find policy for #{row[:policyautoid]} **"
          puts "*" * 80
        end
      end

      # Save the raw data
      xylograph_status = XylographStatus.create!(
        :sale_case_id => sale_case_id,
        :status_auto_id => row[:statusautoid],
        :policy_auto_id => row[:policyautoid],
        :req_number => row[:reqnumber],
        :requirement => row[:requirement],
        :date_requested => row[:daterequested],
        :date_received => row[:datereceived],
        :date_remind => row[:dateremind],
        :responsibility => row[:responsibility],
        :status_flag => row[:statusflag],
        :status_agent_id => row[:statusagentid]
      )

      RES_MAP = { 'Agent' => 'Producer',
                  'Coordinators' => 'NBC' }

      # Now build a Requirement from it
      requirement = Requirement.find_or_initialize_by_original_id(row[:statusautoid])

      requirement.description = 'Imported'
      requirement.sale_case_id = sale_case_id

      requirement.created_at = xylograph_status.date_requested
      requirement.completed_at = xylograph_status.date_received
      requirement.description_note = xylograph_status.requirement
      requirement.responsibility = RES_MAP[xylograph_status.responsibility]

      if ! requirement.save
         puts "Unable to save:"
         puts requirement.errors.full_messages.inspect
         puts requirement.to_yaml

      end

    end # FasterCSV foreach on statuses
  end

# CHATS -> NOTES------------------------------------------------------------------------------------------------------------------
  # Assumes all necessary source files are in /xylograph_data
  # These are all CSV exports from the Xylograph SQL Server database:
  #   GSJ_Chat.txt
  #
  # Exports should use delimited format, Unicode, Column names in first data row, Text qualifier ", Row separator {LF}
  desc 'Import xylograph chat data'
  task :import_chats, [:infile] => :environment do |t, args|
    args.with_defaults(:infile => "GSJ_Chat.txt")
    infile = args.infile

    puts "Importing Chats from #{infile}"

    dry_run = (ENV['DRY_RUN'] == 'true')

    if !dry_run && XylographChat.count > 0
      puts "You appear to have already imported Xylograph Chats"
      return
    end

    unless dry_run
      puts "Oh NOEZ! This isn't a dry run. He's really gonna do it!"
      sleep 5
    end

    i = 1
    FasterCSV.foreach( File.join(RAILS_ROOT, "xylograph_data", infile),
                      { :headers => true, :header_converters => :symbol }
                     ) do |row|
      i += 1

      if dry_run
        puts "Row #{i}: #{row.inspect}"
        next
      else
        # exit
      end

      $stdout.print "."
      $stdout.flush
      puts "\nRow #{i}" if (i % 1000) == 0

      policy_id = row[:policyautoid]

      sale_case = nil
      sale_case_id = nil
      if policy_id.present?
        sale_case = SaleCase.find_by_xyl_policy_identifier(policy_id.strip)
        if sale_case
          sale_case_id = sale_case.id
          $stdout.print "+"
          $stdout.flush
        else
          $stdout.print "?(policy_auto_id:#{policy_id})"
          $stdout.flush
        end
      end

      user_id = nil
      xylograph_user = XylographUser.find_by_agent_id(row[:agentid])
      if xylograph_user
        user_id = xylograph_user.user_id
      end

      puts "Found #{user_id} for User.id and #{sale_case_id} for SaleCase.id" if dry_run

      # Save the raw data
      xylograph_chat = XylographChat.create!(
        :sale_case_id => sale_case_id,
        :user_id => user_id,
        :chat_auto_id => row[:chatautoid],
        :policy_auto_id => row[:policyautoid],
        :status_auto_id => row[:statusautoid],
        :agent_id => row[:agentid],
        :chat_date => row[:chatdate],
        :chat => row[:chat],
        :private => row[:private],
        :chat_status_flag => row[:chatstatusflag]
      )

      # If we can't match this imported record to a SaleCase, don't bother
      # making a Note for it (per Robert)
      next unless sale_case

      # SaleCase objects should have one Requirement attached with a description
      # of "Case Notes".  It could theoretically have more than one, though it
      # doesn't appear to need it.  Anyway, we're going to need to attach any
      # notes we create here to that one Requirement, so we need to make sure
      # it has one, because some may have slipped through during some import
      # process and not had a "Case Notes" Requirement attached.

      sale_case.create_initial_case_requirement

      requirement = sale_case.requirements.case_notes.first
      if requirement.nil?
        puts "ERROR: Couldn't find a 'Case Notes' requirement for SaleCase ##{sale_case.id}. Note not created."
        next
      end

      # Now build a Note from it
      note = Note.find_or_initialize_by_original_id_and_original_type(row[:chatautoid], 'XylographChat')

      note.user_id = user_id

      note.comment = "Imported: " + xylograph_chat.chat

      # We only care about the ones we can connect to a SaleCase. But we're going
      # to treat them all as SaleCase-connected ones.  We'll actually connect it
      # to the SaleCase's special "Case Notes" Requirement, since that's where all
      # the notes attach (acts_as_notable) for a SaleCase.

      note.notable_type = 'Requirement'
      note.notable_id = requirement.id

      note.created_at = xylograph_chat.chat_date
      note.access_level = 'staff'

      if ! note.save
         puts "unable to save:"
         puts note.errors.full_messages.inspect
         puts note.to_yaml
      end

    end # FasterCSV foreach on chat
  end

  # ATTACHMENTS -> ATTACHMENTS ------------------------------------------------------------------------------------------------------------------
  # Assumes all necessary source files are in /xylograph_data
  # These are all CSV exports from the Xylograph SQL Server database:
  #   GSJ_Attachments.txt
  #
  # Exports should use delimited format, Unicode, Column names in first data row, Text qualifier ", Row separator {LF}
  desc 'Import xylograph attachments data'
  task :import_attachments, [:infile] => :environment do |t, args|
    args.with_defaults(:infile => "GSJ_Attachments.txt")
    infile = args.infile

    puts "Importing Attachments from #{infile}"

    dry_run = (ENV['DRY_RUN'] == 'true')

    if !dry_run && XylographAttachment.count > 0
      puts "You appear to have already imported Xylograph Attachments"
      return
    end

    unless dry_run
      puts "Oh NOEZ! This isn't a dry run. He's really gonna do it!"
      sleep 5
    end

    i = 1
    FasterCSV.foreach( File.join(RAILS_ROOT, "xylograph_data", infile),
                      { :headers => true, :header_converters => :symbol }
                     ) do |row|
      i += 1

      if dry_run
        puts "Row #{i}: #{row.inspect}"
        next
      else
        # exit
      end

      $stdout.print "."
      $stdout.flush
      puts "\nRow #{i}" if (i % 1000) == 0

      policy_id = row[:policyautoid]

      sale_case = nil
      sale_case_id = nil
      new_case = false
      unless policy_id.nil?
        sale_case = SaleCase.find_by_xyl_policy_identifier(policy_id.strip)
        if sale_case
          sale_case_id = sale_case.id
          $stdout.print "."
          $stdout.flush
        else
          $stdout.print "?(policy_auto_id:#{policy_id})"
          $stdout.flush
        end
      end

      puts "Found #{sale_case_id} for SaleCase.id" if dry_run

      # Save the raw data
      xylograph_attachment = XylographAttachment.create!(
        :sale_case_id => sale_case_id,
        :attachment_auto_id => row[:attachmentautoid],
        :policy_auto_id => row[:policyautoid],
        :status_auto_id => row[:statusautoid],
        :attachment_file_name => row[:attachmentfilename],
        :attachment_label => row[:attachmentlabel],
        :upload_date => row[:uploaddate],
        :private => row[:private]
      )

      # Now build a SaleCaseAttachment from it
      attachment = SaleCaseAttachment.find_or_initialize_by_original_id(row[:attachmentautoid])

      attachment.sale_case_id = sale_case_id

      attachment.attachment_file_name = xylograph_attachment.attachment_file_name
      attachment.description = "Imported: " + xylograph_attachment.attachment_label
      attachment.created_at = xylograph_attachment.upload_date
      attachment.producer_viewable = false # Private doesn't mean the same thing in old data so set to false to be safe
      attachment.attachment_content_type = "application/pdf"
      attachment.attachment_file_size = -1   # We have no idea, so let's make sure that's clear
      attachment.attached_by = nil

      if ! attachment.save
         puts "unable to save:"
         puts attachment.to_yaml
      end

    end # FasterCSV foreach on attachments
  end

# ------------------------------------------------------------------------------------------------------------------
  # Used to set User notification_email from XylographUser status_email.
  # This was missed in the intial import import_user
  desc "Set Sale Case notification_email mapped from xylograph user status_email"
  task :set_notification_email => :environment do
    i = 1
    dry_run = (ENV['DRY_RUN'] == 'true')
    if dry_run
      puts "Relax; this is just a dry run for the real thing."
    end
    XylographUser.find(:all, :order => "user_id DESC").each do |xylograph_user|
      unless xylograph_user.status_email.nil? || xylograph_user.user_id.nil?
        notification_email = xylograph_user.status_email || '' rescue ''
        # Might as well filter out bad emails
        notification_email = "" if ['noemail@noemail.com', 'noemail@norcalbrokerage.com', 'noemail@glic.com', 'xxx.com' ].include? notification_email
        if user = xylograph_user.user
          if dry_run
            puts "Notification email for #{user.display_name} (#{user.id}) will be set to: #{notification_email} (#{xylograph_user.status_email})\n"
            i += 1
            $stdout.print "."
            $stdout.flush
            puts "\n#{i} Completed" if (i % 1000) == 0
          else
            xylograph_user.user.notification_email = notification_email
            if xylograph_user.user.save
              puts "Notification email for #{user.display_name} (#{user.id}) was set to: #{notification_email}"
              i += 1
              $stdout.print "."
              $stdout.flush
              puts "\n#{i} Completed" if (i % 1000) == 0
            else
              puts "\n User notification_email was NOT able to be saved"
              puts xylograph_user.user.errors.full_messages.inspect
              puts xylograph_user.user.to_yaml
            end
          end
        end
      end
    end
  end

# ------------------------------------------------------------------------------------------------------------------
  # Used to set SaleCase workflow_state from Xylograph status.
  # This was missed in the intial import (import_policies), but is included in future imports.
  desc "Set Sale Case status mapped from xylograph policy status"
  task :set_status => :environment do
    i = 1
    mappings = {'Approved'          => 'approved',
                'Closed/Incomplete' => 'closed_incomplete',
                'Change'            => 'inforce',
                'Declined'          => 'declined',
                'Gone To Issue'     => 'gone_to_issue',
                'Hold'              => 'application_hold',
                'Issued/Not Paid'   => 'issued_not_paid',
                'Paid'              => 'paid',
                'Pending'           => 'pending',
                'Postponed'         => 'postponed',
                'Refused/NTO'       => 'not_taken_other',
                'Reinsurance'       => 'to_reinsurance',
                'Reissue'           => 'reissue_requested',
                'Tentative Offer'   => 'tentative_offer'}

    XylographPolicy.find(:all, :order => "sale_case_id DESC").each do |xylograph_policy|
      unless xylograph_policy.status.nil? || xylograph_policy.sale_case_id.nil?
        status = mappings[xylograph_policy.status] || 'unknown' rescue 'unknown'
        xylograph_policy.sale_case.workflow_state = status
        if xylograph_policy.sale_case.save
          i += 1
          $stdout.print "."
          $stdout.flush
          puts "\n#{i} Completed" if (i % 1000) == 0
        else
          puts "\n Case status was NOT saved"
        end
      end
    end
  end

# ------------------------------------------------------------------------------------------------------------------
  desc "Copy SaleCase workflow_state from status"
  task :copy_workflow_state_from_status => :environment do
    i = 1
    SaleCase.all.each do |sale_case|
      sale_case.workflow_state = sale_case.status if sale_case.status
      sale_case.save
      i += 1
      $stdout.print "."
      $stdout.flush
      puts "\n#{i} Completed" if (i % 1000) == 0
    end
  end

# ------------------------------------------------------------------------------------------------------------------
  desc "Downcase all Guardian People Email Addresses"
  task :downcase_guardian_people_emails => :environment do
    i = 1
    GuardianPerson.all.each do |guardian_person|
      if guardian_person.email
        guardian_person.email = guardian_person.email.downcase
      else
        guardian_person.email = (guardian_person.first_name + "_" + guardian_person.last_name + "@notset.com").downcase
      end

      if guardian_person.initials.blank?
        guardian_person.initials = (guardian_person.first_name[0,1] + guardian_person.last_name[0,1]).downcase
      end

      if guardian_person.save
        i += 1
        $stdout.print "."
        $stdout.flush
        puts "\n#{i} Completed" if (i % 1000) == 0
      else
        puts "Unable to save:"
        puts guardian_person.errors.full_messages.inspect
        puts guardian_person.to_yaml
      end
    end
  end

# ------------------------------------------------------------------------------------------------------------------
  desc "Clean up imported email addresses"
  task :clean_imported_email_addresses => :environment do

    dry_run = (ENV['DRY_RUN'] == 'true')
    if dry_run
      puts "Relax; this is just a dry run for the real thing."
    end

    i = 0
    User.all.each do |user|
      if user.email
        address, crud = user.email.split(',')
        unless crud.nil?
          puts "Removed '#{crud}' from #{user.full_name} (#{user.id}) address. Cleaned email: #{address}"
        end
        user.email = address
        user.alt_email = crud
      end

      unless dry_run
        if user.save
          i += 1
          $stdout.print "."
          $stdout.flush
          puts "\n#{i} Completed" if (i % 1000) == 0
        else
          puts "Unable to save:"
          puts user.errors.full_messages.inspect
          puts user.to_yaml
        end
      end
    end
  end

# ------------------------------------------------------------------------------------------------------------------
  desc "Associate Xylograph Underwriter"
  task :associate_xylograph_uw => :environment do
    i = 1
    SaleCase.all.each do |sale_case|
      xylograph_policy = XylographPolicy.find_by_policy_auto_id(sale_case.xyl_policy_identifier)
      if xylograph_policy
        if xylograph_policy.underwriter
          name_parts = xylograph_policy.underwriter.split
          first_name = name_parts[0]
          last_name = name_parts[-1]
          # underwriter = GuardianPerson.find(:first, :conditions => ["last_name = ? and first_name = ?", last_name, first_name])
          underwriter = GuardianPerson.find_by_first_name_and_last_name(first_name, last_name)
          if underwriter
            sale_case.glic_underwriter = underwriter
            if sale_case.save
              i += 1
              $stdout.print "+"
              $stdout.flush
              puts "\n#{i} Completed" if (i % 1000) == 0
            else
              puts "Unable to save:"
              puts sale_case.errors.full_messages.inspect
              puts sale_case.to_yaml
            end
          end
        end
      end
    end
  end

# ------------------------------------------------------------------------------------------------------------------
  desc "Update correct NBU Staff ids to cases"
  task :update_nbu_ids  => :environment do
    nbu_staff = {
      6171  => 7021,
      45231 => 284,
      9551  => 10981,
      10681 => 12381,
      20161 => 23871,
      21411 => 49141,
      26451 => 31301,
      28821 => 34151,
      31391 => 37141,
      31911 => 37751,
      40491 => 47981,
      47101 => 33301,
      12531 => 14631,
      42081 => 7401,
      35881 => 42361,
      34851 => 41111
    }
    nbu_staff.each do |k, v|
      sale_cases = SaleCase.find_all_by_nbu_coordinator_id(k)
      count = sale_cases.count
      puts "\nUpdating #{count} cases for nbu id #{v}"
      sale_cases.each do |sale_case|
        sale_case.update_attribute(:nbu_coordinator_id, v)
        $stdout.print "."
        $stdout.flush
      end
    end
  end

# ------------------------------------------------------------------------------------------------------------------
  desc "Update supervisor users for agents"
  task :update_supervisor_ids  => :environment do
    User.all.each do |user|
      unless user.agent_identifier.blank?
        if xylograph_user = XylographUser.find_by_agent_id(user.agent_identifier)

          puts "\nUpdating Supervisor Info for User: #{user.display_name} "

          puts "Primary Supervisor: #{xylograph_user.supervisor_id} / DI Supervisor: #{xylograph_user.supervisor_disid} / Life Supervisor: #{xylograph_user.supervisor_lifeid} / LTC Supervisor: #{xylograph_user.supervisor_ltcid}"

          unless xylograph_user.supervisor_id.blank? || xylograph_user.supervisor_id == "Administrator" || xylograph_user.supervisor_id == "callcanter" || xylograph_user.supervisor_id == "Unassigned"
            if primary_supervisor = XylographUser.find_by_agent_id(xylograph_user.supervisor_id)
              user.supervisor_primary_id = primary_supervisor.user_id if primary_supervisor
              $stdout.print "+"
              $stdout.flush
            else
              $stdout.print "?"
              $stdout.flush
            end
          end

          unless xylograph_user.supervisor_disid.blank? || xylograph_user.supervisor_disid == "Administrator" || xylograph_user.supervisor_disid == "callcanter" || xylograph_user.supervisor_disid == "Unassigned"
            if di_supervisor = XylographUser.find_by_agent_id(xylograph_user.supervisor_disid)
              user.supervisor_di_id = di_supervisor.user_id if di_supervisor
              $stdout.print "+"
              $stdout.flush
            else
              $stdout.print "?"
              $stdout.flush
            end
          end

          unless xylograph_user.supervisor_ltcid.blank? || xylograph_user.supervisor_ltcid == "Administrator" || xylograph_user.supervisor_ltcid == "callcanter" || xylograph_user.supervisor_ltcid == "Unassigned"
            if life_supervisor = XylographUser.find_by_agent_id(xylograph_user.supervisor_ltcid)
              user.supervisor_life_id = life_supervisor.user_id if life_supervisor
              $stdout.print "+"
              $stdout.flush
            else
              $stdout.print "?"
              $stdout.flush
            end
          end

          unless xylograph_user.supervisor_lifeid.blank? || xylograph_user.supervisor_lifeid == "Administrator" || xylograph_user.supervisor_lifeid == "callcanter" || xylograph_user.supervisor_lifeid == "Unassigned"
            if ltc_supervisor = XylographUser.find_by_agent_id(xylograph_user.supervisor_lifeid)
              user.supervisor_ltc_id = ltc_supervisor.user_id if ltc_supervisor
              $stdout.print "+"
              $stdout.flush
            else
              $stdout.print "?"
              $stdout.flush
            end
          end
          user.save

        end
      end
    end
  end

# ------------------------------------------------------------------------------------------------------------------
  desc "Update Sale Case Shares from Xylograph Policies"
  task :update_sale_case_shares  => :environment do

    # Setup for console feedback during task
    i = 0
    count = XylographPolicy.count
    puts "Updating #{count} Xylograph Policy Share info to the proper Sale Cases"

    XylographPolicy.all.each do |xylograph_policy|

      # Provide some console feedback during task
      i = i+1
      if i % 1000 == 0
        puts "Row #{i} of #{count} (%.2f %% complete)" % (100 * i.to_f / count)
      end

      if xylograph_policy.sale_case_id
        sale_case = SaleCase.find(xylograph_policy.sale_case_id)
        if sale_case

          # Delete any existing sale_case_shares
          sale_case.sale_case_shares.each do |share|
            share.destroy
          end

          if xylograph_policy.agent_id && xylograph_policy.agent_id_cut
            user = User.find_by_agent_identifier(xylograph_policy.agent_id)
            if user
              SaleCaseShare.create(:producer_id => user.id, :sale_case_id => sale_case.id, :share => (xylograph_policy.agent_id_cut.to_i))
            end
          end

          if xylograph_policy.agent_id2 && xylograph_policy.agent_id2_cut
            user = User.find_by_agent_identifier(xylograph_policy.agent_id2)
            if user
              SaleCaseShare.create(:producer_id => user.id, :sale_case_id => sale_case.id, :share => (xylograph_policy.agent_id2_cut.to_i))
            end
          end

          if xylograph_policy.agent_id3 && xylograph_policy.agent_id3_cut
            user = User.find_by_agent_identifier(xylograph_policy.agent_id3)
            if user
              SaleCaseShare.create(:producer_id => user.id, :sale_case_id => sale_case.id, :share => (xylograph_policy.agent_id3_cut.to_i))
            end
          end

          if xylograph_policy.agent_id4 && xylograph_policy.agent_id4_cut
            user = User.find_by_agent_identifier(xylograph_policy.agent_id4)
            if user
              SaleCaseShare.create(:producer_id => user.id, :sale_case_id => sale_case.id, :share => (xylograph_policy.agent_id4_cut.to_i))
            end
          end

          if xylograph_policy.agent_id5 && xylograph_policy.agent_id5_cut
            user = User.find_by_agent_identifier(xylograph_policy.agent_id5)
            if user
              SaleCaseShare.create(:producer_id => user.id, :sale_case_id => sale_case.id, :share => (xylograph_policy.agent_id5_cut.to_i))
            end
          end

          if xylograph_policy.agent_id6 && xylograph_policy.agent_id6_cut
            user = User.find_by_agent_identifier(xylograph_policy.agent_id6)
            if user
              SaleCaseShare.create(:producer_id => user.id, :sale_case_id => sale_case.id, :share => (xylograph_policy.agent_id6_cut.to_i))
            end
          end
          $stdout.print "."
          $stdout.flush

        end # if sale_case
      end # if xylograph_policy.sale_case_id
    end # XylographPolicy.each do |xylograph_policy|
  end  # task :update_sale_case_shares do


# ------------------------------------------------------------------------------------------------------------------
  # Use this once before running the updated import_policies rake task, which looks for policyautoid in xyl_policy_identifier col
  # Assumes all necessary source files are in /xylograph_data
  # These are all CSV exports from the Xylograph SQL Server database:
  #   GSJ_Policies.txt
  #
  # Exports should use delimited format, Unicode, Column names in first data row, Text qualifier ", Row separator {LF}
  desc 'Correlate existing SaleCases to xylograph policies'
  task :correlate_policies, [:infile] => :environment do |t, args|
    args.with_defaults(:infile => "GSJ_Policies.txt")
    infile = args.infile

    puts "Finding SaleCases that correlate to Policies from #{infile}"

    FasterCSV.foreach(File.join(RAILS_ROOT, "xylograph_data", infile), {:headers => true, :header_converters => :symbol}) do |row|
      if ENV['DRY_RUN'] == 'true'
        puts row.inspect
      else
        sale_case_id = nil
        new_case = false

        unless row[:policynumber].nil?
          sale_case = SaleCase.find_by_policy_number(row[:policynumber].strip)
          if sale_case
            sale_case_id = sale_case.id
            sale_case.xyl_policy_identifier = row[:policyautoid]
            sale_case.save
            $stdout.print "+"
            $stdout.flush
          else
            $stdout.print "?"
            $stdout.flush
          end
        end
      end
    end # FasterCSV foreach on policies
  end



# ------------------------------------------------------------------------------------------------------------------
  # Use this once before running the updated import_policies rake task, which looks for policyautoid in xyl_policy_identifier col
  # Assumes all necessary source files are in /xylograph_data
  # These are all CSV exports from the Xylograph SQL Server database:
  #   GSJ_Policies.txt
  #
  # Exports should use delimited format, Unicode, Column names in first data row, Text qualifier ", Row separator {LF}
  desc 'Associate NBU Coordinators to Sale Cases'
  task :correlate_nbu_coordinators, [:infile] => :environment do |t, args|
    args.with_defaults(:infile => "GSJ_Policies.txt")
    infile = args.infile

    puts "Associating NBU Coordinators to Policies from #{infile}"

    FasterCSV.foreach(File.join(RAILS_ROOT, "xylograph_data", infile), {:headers => true, :header_converters => :symbol}) do |row|
      if ENV['DRY_RUN'] == 'true'
        puts row.inspect
      else
        sale_case = SaleCase.find_by_xyl_policy_identifier(row[:policyautoid].strip)
        if sale_case
          nbu_staff_mappings = {  'ani007'      => 291,
                                'serventeka'  => 304,
                                'thomasonma'  => 308,
                                'Smithka'     => 4451,
                                'Arias007'    => 7021,
                                'brownde'     => 10981,
                                'CarvajalEd'  => 12381,
                                'holmesje'    => 23871,
                                'jjones'      => 49141,
                                'Mats007'     => 31301,
                                'NelsonAr'    => 34151,
                                'poe007'      => 37141,
                                'ram007'      => 37751,
                                'WitteTo'     => 47981,
                                'Hriss007'    => 284,
                                'Mooreken'    => 33301,
                                'cortezsh'    => 14631,
                                'Avilaju'     => 7401,
                                'SmithDe'     => 42361,
                                'segovianode' => 41111
                              }
          sale_case.nbu_coordinator_id = nbu_staff_mappings[row[:coordinatorid]] || nil
          sale_case.save
          $stdout.print "+"
          $stdout.flush
        else
          $stdout.print "?(policy_auto_id:#{row[:policyautoid]})"
          $stdout.flush
        end
      end # if dry_run
    end # FasterCSV foreach on policies
  end


# ------------------------------------------------------------------------------------------------------------------
  # Assumes all necessary source files are in /xylograph_data
  # These are all CSV exports from the Xylograph SQL Server database:
  #   GSJ_Underwriters.txt
  # Exports should use delimited format, Unicode, Column names in first data row, Text qualifier ", Row separator {LF}
  desc 'Import underwriters'
  task :import_underwriters, [:infile] => :environment do |t, args|
    args.with_defaults(:infile => "GSJ_Underwiters.txt")
    infile = args.infile

    puts "Importing Underwriters from #{infile}."

    FasterCSV.foreach(File.join(RAILS_ROOT, "xylograph_data", infile), {:headers => true, :header_converters => :symbol}) do |row|
      if ENV['DRY_RUN'] == 'true'
        puts row.inspect
      else
        if row[:uwemail]
          guardian_person = GuardianPerson.find_by_email(row[:uwemail].downcase)
        end
        if guardian_person
          guardian_person.xyl_identifier = row[:uwautoid]
          $stdout.print "."
          $stdout.flush
        else
          guardian_person = GuardianPerson.new
          guardian_person.last_name = row[:uwlastname]
          guardian_person.first_name = row[:uwfirstname]
          if row[:uwemail]
            guardian_person.email = row[:uwemail].downcase
          else
            guardian_person.email = "unknown"
          end
          guardian_person.initials = guardian_person.first_name[0,3] + guardian_person.last_name[0,3]
          guardian_person.phone = "unknown"
          $stdout.print "+"
          $stdout.flush
        end

        unless guardian_person.save
          puts "Unable to save:"
          puts guardian_person.errors.full_messages.inspect
          puts guardian_person.to_yaml
        end

      end
    end # FasterCSV foreach on policies
  end

end

def find_user_for_xylograph_id(xylograph_user_id, verbose = false)
  user = nil
  if xylograph_user = XylographUser.find_by_agent_id(xylograph_user_id)
    if user_id = xylograph_user.user_id
      user = User.find(user_id)
      if verbose && user.nil?
        puts "COULD NOT FIND A USER FOR #{xylograph_user}"
      end
    end
  end
  user
end

def ask(message)
  print message
  STDIN.gets.chomp
end
