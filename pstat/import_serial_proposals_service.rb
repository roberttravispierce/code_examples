# frozen_string_literal: true

# Invoke: > ImportSerialProposalsService.new.call
class ImportSerialProposalsService
  DATA_FILE = File.join(Rails.root, 'db/seeds/serial_proposals/serial_proposals.yml')
  LOGFILE = ActiveSupport::Logger.new('log/import_serial_proposals.log')
  DEFAULT_NETWORK = "3ABN Parent Network"

  def call
    serial_proposal_entries.each do |serial_proposal_entry|
      create_serial_proposal(serial_proposal_entry)
    end
  end

  def serial_proposal_entries
    serial_proposals_seed = YAML.load_file(DATA_FILE)
    serial_proposals_seed['serial_proposals']
  end

  def create_serial_proposal(serial_proposal_entry)
    SerialProposal.where(working_title: serial_proposal_entry['working_title']).first_or_initialize do |new_serial_proposal|
      new_serial_proposal.working_title = serial_proposal_entry['working_title']
      new_serial_proposal.title_search_notes = serial_proposal_entry['title_search_notes']
      new_serial_proposal.working_code = serial_proposal_entry['working_code']
      new_serial_proposal.purpose = serial_proposal_entry['purpose']
      new_serial_proposal.timeline_notes = serial_proposal_entry['timeline_notes']
      new_serial_proposal.status = serial_proposal_entry['status']
      new_serial_proposal.producer = serial_proposal_entry['producer']
      new_serial_proposal.hosts = serial_proposal_entry['hosts']
      new_serial_proposal.program_type = serial_proposal_entry['program_type']
      new_serial_proposal.audience_type = serial_proposal_entry['audience_type']
      new_serial_proposal.audience_notes = serial_proposal_entry['audience_notes']
      new_serial_proposal.location_type = serial_proposal_entry['location_type']
      new_serial_proposal.location_notes = serial_proposal_entry['location_notes']
      new_serial_proposal.season_episodes = serial_proposal_entry['season_episodes']
      new_serial_proposal.season_notes = serial_proposal_entry['season_notes']
      new_serial_proposal.length = serial_proposal_entry['length']
      new_serial_proposal.length_notes = serial_proposal_entry['length_notes']
      new_serial_proposal.segment_notes = serial_proposal_entry['segment_notes']
      new_serial_proposal.gender = serial_proposal_entry['gender']
      new_serial_proposal.affiliation = serial_proposal_entry['affiliation']
      new_serial_proposal.teleprompter_notes = serial_proposal_entry['teleprompter_notes']
      new_serial_proposal.script_notes = serial_proposal_entry['script_notes']
      new_serial_proposal.set_type = serial_proposal_entry['set_type']
      new_serial_proposal.set_notes = serial_proposal_entry['set_notes']
      new_serial_proposal.graphics_notes = serial_proposal_entry['graphics_notes']
      new_serial_proposal.music_notes = serial_proposal_entry['music_notes']
      network_name = serial_proposal_entry['network_name'].blank? ? DEFAULT_NETWORK : serial_proposal_entry['network_name']
      new_serial_proposal.network = Network.find_by_full_name(network_name)
      new_serial_proposal.save!(validate: false)
      add_log_entry "************** Created Serial Proposal: #{new_serial_proposal.working_title}"
    end
  end

  def add_log_entry(entry = '')
    p entry
    LOGFILE.info entry
  end

  LOGFILE.close
end
