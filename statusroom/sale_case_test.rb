# require 'test_helper'
require File.dirname(__FILE__) + "/../test_helper"

class SaleCaseTest < ActiveSupport::TestCase
  setup do
    @account = Factory.create(:account, :agency_code => 'DE')
    @account.users << (@user = Factory.build(:advisor, :account => @account))
  end

  context "smoke test" do
    should "be createable" do
      assert Factory.create(:sale_case).valid?
    end
  end

  # TODO: Generalize this as shoulda extension
  context "paper trail" do
    should_have_class_methods :paper_trail_active
    should_callback :record_create, :after_create
    should_callback :record_update, :before_update
    should_callback :record_destroy, :after_destroy
  end

  should_have_many :sale_case_relationships #, :after_add => :reciprocate_relationship, :after_remove => :remove_relationship
  should_have_many :related_sale_cases, :through => :sale_case_relationships
  should_have_many :premiums
  should_have_many :policy_events
  should_have_many :policy_shares
  should_have_many :advisors
  should_have_many :forecasts
  should_have_many :messages #, :as => :discussable
  should_have_many :requirements
  should_have_many :quotes
  should_have_many :activities
  should_have_many :all_activities

  should_eventually "act_as_notable"

  context "reciprocal relationships" do
    should "add an inverse relation when adding a relation" do
      sale_case1 = Factory.create(:sale_case)
      sale_case2 = Factory.create(:sale_case)
      sale_case1.related_sale_cases << sale_case2
      assert sale_case2.related_sale_cases.include?(sale_case1)
    end

    should "remove the inverse relation when removing a relation" do
      sale_case1 = Factory.create(:sale_case)
      sale_case2 = Factory.create(:sale_case)
      sale_case1.related_sale_cases << sale_case2
      assert sale_case2.related_sale_cases.include?(sale_case1)
      sale_case1.related_sale_cases.clear
      assert !sale_case2.related_sale_cases.include?(sale_case1)
    end
  end

  should_validate_presence_of :insured_last_name, :insured_first_name, :policy_type # can't actually create w/o workflow_state

  should_allow_mass_assignment_of :name,
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

  context "#to_param" do
    should "combine id, policy_type, and owner_last_name" do
      sale_case = Factory.build(:sale_case, :id => 5, :policy_type => "life", :insured_last_name => "hamburger")
      assert_equal "5-life-hamburger", sale_case.to_param
    end

    should "remove special characters from policy type" do
      sale_case = Factory.build(:sale_case, :id => 5, :policy_type => "disability*", :insured_last_name => "hamburger")
      assert_equal "5-disability--hamburger", sale_case.to_param
    end

    should "remove special characters from owner last name" do
      sale_case = Factory.build(:sale_case, :id => 5, :policy_type => "life", :insured_last_name => "$0.50")
      assert_equal "5-life--0-50", sale_case.to_param
    end

    should "force lower case" do
      sale_case = Factory.build(:sale_case, :id => 5, :policy_type => "Life", :insured_last_name => "McGuffin")
      assert_equal "5-life-mcguffin", sale_case.to_param
    end
  end

  context "#case_name" do
    should "return the policy number if available" do
      sale_case = Factory.build(:sale_case, :policy_number => 'ABC123', :policy_type => 'LTC', :id => 357)
      assert_equal 'ABC123', sale_case.case_name
    end

    should "synthesize a Z number for LTC" do
      sale_case = Factory.build(:sale_case, :policy_number => nil, :policy_type => 'LTC', :id => 357)
      assert_equal 'DEZ000357', sale_case.case_name
    end

    should "synthesize a K number for DI" do
      sale_case = Factory.build(:sale_case, :policy_number => nil, :policy_type => 'DI', :id => 357)
      assert_equal 'DEK000357', sale_case.case_name
    end

    should "synthesize a 0 number for Life" do
      sale_case = Factory.build(:sale_case, :policy_number => nil, :policy_type => 'LIFE', :id => 357)
      assert_equal 'DE0000357', sale_case.case_name
    end
  end

  context "#case_long_name" do
    should "combine case name and owner name" do
      sale_case = Factory.build(:sale_case, :policy_number => 'ABC123', :insured_first_name => 'Ryan', :insured_last_name => 'Fonebone', :policy_type => 'LTC')
      assert_equal 'ABC123 (Fonebone, Ryan)', sale_case.case_long_name
    end
  end

  context "#premium_to_display" do
    should "return the issued premium if available" do
      sale_case = Factory.build(:sale_case, :policy_number => 'ABC123', :total_annual_premium_issued => 1773.5, :total_annual_premium => 9999, :id => 357)
      assert_equal 1773.5, sale_case.premium_to_display
    end

    should "return the submitted premium if issued not available" do
      sale_case = Factory.build(:sale_case, :policy_number => 'ABC123', :total_annual_premium_issued => nil, :total_annual_premium => 9999, :id => 357)
      assert_equal 9999, sale_case.premium_to_display
    end

    should "return zero if neither premium type is available" do
      sale_case = Factory.build(:sale_case, :policy_number => 'ABC123', :total_annual_premium_issued => nil, :total_annual_premium => nil, :id => 357)
      assert_equal 0, sale_case.premium_to_display
    end
  end

  context "named_scope status_date_this_year" do
    # named_scope :status_date_this_year, :conditions => ["status_date > ?", Date.today << 12]
    should "should return sale cases with status dates newer than one year ago" do
      assert SaleCase.respond_to?(:status_date_this_year)
      expected = {:conditions=>["status_date > ?", Date.today << 12]}
      assert_equal expected, SaleCase.status_date_this_year.proxy_options
    end
  end

  context "A Sale Case" do

    ## TODO: Is this necessary? See comment re: uniqueness in sale_case.rb
    #
    # should "have a unique policy number" do
    #   sale_case  = Factory.build(:sale_case, :policy_number => "AB123")
    #   assert sale_case.save!
    #   sale_case2 = Factory.build(:sale_case, :policy_number => "AB123")
    #   assert_raises ActiveRecord::RecordInvalid do
    #     sale_case2.save!
    #   end
    #   assert_match "Policy number has already been taken", sale_case2.errors.full_messages * ' '
    # end

    context "#short_display" do
      should "combine policy number and insured last name" do
        @sale_case = Factory.build(:policy, :policy_number => "G833087", :insured_last_name => "Squirrel")
        assert_equal "G833087 Squirrel", @sale_case.short_display
      end

      should "handle policy number only" do
        @sale_case = Factory.build(:policy, :policy_number => "G833087", :insured_last_name => "")
        assert_equal "G833087", @sale_case.short_display
      end

      should "handle insured last name only" do
        @sale_case = Factory.build(:policy, :policy_number => "", :insured_last_name => "Squirrel")
        assert_equal "Squirrel", @sale_case.short_display
      end
    end

  end

  # TODO: Fix this test. not sure why it's failing -RTP 20101202
  context "#all_notes" do
    should_eventually "combine sale_case notes and requirement notes" do
      sale_case = Factory.create(:sale_case)
      note1 = Factory.create(:note, :notable_id => sale_case.id, :notable_type => 'SaleCase')
      requirement = Factory.create(:requirement, :sale_case_id => sale_case.id)
      note2 = Factory.create(:note, :notable_id => requirement.id, :notable_type => 'Requirement')
      assert_equal [note1, note2].map(&:id).to_set, sale_case.all_notes.map(&:id).to_set
    end
  end

  context "named scopes for daily mail" do
    setup do
      @sale_case_1 = Factory.create(:sale_case, :updated_at => 2.days.ago)
      @sale_case_2 = Factory.create(:sale_case, :updated_at => 6.hours.ago)

      @sale_case_3 = Factory.create(:sale_case, :updated_at => 2.days.ago)
      @requirement_1 = Factory.create(:requirement, :sale_case_id => @sale_case_3.id, :updated_at => 2.days.ago)

      @sale_case_4 = Factory.create(:sale_case, :updated_at => 2.days.ago)
      @requirement_2 = Factory.create(:requirement, :sale_case_id => @sale_case_4.id, :updated_at => 6.hours.ago)

      @sale_case_5 = Factory.create(:sale_case, :updated_at => 2.days.ago)
      @requirement_3 = Factory.create(:requirement, :sale_case_id => @sale_case_5.id, :updated_at => 2.days.ago)
      @note_1 = Factory.create(:note, :notable_id => @requirement_3.id, :notable_type => 'Requirement', :updated_at => 2.days.ago)

      @sale_case_6 = Factory.create(:sale_case, :updated_at => 2.days.ago)
      @requirement_4 = Factory.create(:requirement, :sale_case_id => @sale_case_6.id, :updated_at => 2.days.ago)
      @note_2 = Factory.create(:note, :notable_id => @requirement_4.id, :notable_type => 'Requirement', :updated_at => 6.hours.ago)
    end

    context ".updated_since" do
      should "include cases touched after the specified time" do
        assert SaleCase.updated_since(1.day.ago).map(&:id).include?(@sale_case_2.id)
      end

      should "not include cases touched before the specified time" do
        assert !SaleCase.updated_since(1.day.ago).map(&:id).include?(@sale_case_1.id)
      end
    end

    context ".requirement_updated_since" do
      should "include cases with requirements touched after the specified time" do
        assert SaleCase.requirement_updated_since(1.day.ago).map(&:id).include?(@sale_case_4.id)
      end

      # NOTE: Fails b/c of the automatically created "case notes" requirement
      should_eventually "not include cases with requirements touched before the specified time" do
        assert !SaleCase.requirement_updated_since(1.day.ago).map(&:id).include?(@sale_case_3.id)
      end
    end

    context ".note_updated_since" do
      should "include cases with notes touched after the specified time" do
        assert SaleCase.note_updated_since(1.day.ago).map(&:id).include?(@sale_case_6.id)
      end

      should "not include cases with notes touched before the specified time" do
        assert !SaleCase.note_updated_since(1.day.ago).map(&:id).include?(@sale_case_5.id)
      end
    end

  end

  context "#responsible_sale_case_id" do
    should "return this case's id" do
       @sale_case = Factory.create(:sale_case)
       assert_equal @sale_case.id, @sale_case.responsible_sale_case_id
    end
  end

  context "activity tracking" do
    should "create an activity for a new case" do
      sale_case = Factory.build(:sale_case)
      sale_case.save!
      activity = Activity.last
      assert_equal sale_case, activity.trackable
      assert_equal "New", activity.change_type
      assert_equal "A new case was created.", activity.description
    end

    should "create an activity for a changed case" do
      sale_case = Factory.build(:sale_case, :us_state => "CA")
      sale_case.save!
      sale_case.us_state = "IN"
      sale_case.save!
      activity = Activity.last
      assert_equal sale_case, activity.trackable
      assert_equal "Changed", activity.change_type
      assert_equal "This case has changed: State was changed from CA to IN.", activity.description
    end
  end
end

