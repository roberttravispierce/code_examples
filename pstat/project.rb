# == Schema Information
#
# Table name: projects
#
#  id                :bigint           not null, primary key
#  audio_info        :jsonb
#  audio_lead        :string
#  delivered_at      :datetime
#  delivered_by      :string
#  delivery_editor   :string
#  delivery_notes    :text
#  description       :text
#  dist_channels     :string
#  dist_code         :string
#  dist_description  :text
#  dist_notes        :text
#  dist_title        :string
#  dist_trt_str      :string
#  distributed_at    :datetime
#  est_trt           :string
#  first_air_date    :datetime
#  guests            :text
#  hosts             :text
#  live_editor       :string
#  music_notes       :text
#  name              :string
#  notes             :text
#  other_air_dates   :text
#  pcode             :integer
#  phase             :integer          default("initiated"), not null
#  prov_dist_code    :string
#  ptype             :integer          default("episode")
#  qc_approved_at    :datetime
#  qc_approver       :string
#  recorded_at       :datetime
#  release_date      :datetime
#  sched_record_date :datetime
#  slug              :string
#  state             :integer          default("in_production")
#  year              :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  network_id        :bigint
#  serial_id         :bigint
#
# Indexes
#
#  index_projects_on_dist_code   (dist_code)
#  index_projects_on_network_id  (network_id)
#  index_projects_on_pcode       (pcode) UNIQUE
#  index_projects_on_serial_id   (serial_id)
#  index_projects_on_slug        (slug) UNIQUE
#  index_projects_on_state       (state)
#  index_projects_on_year        (year)
#

class Project < ApplicationRecord
  searchkick

  before_validation :recheck_last_pcode, on: [:create]

  store_accessor :audio_info,
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

  def search_data
    {
      name: name,
      pcode: pcode.to_s,
      dist_code: dist_code,
      dist_description: dist_description,
      dist_title: dist_title,
      description: description,
      hosts: hosts,
      guests: guests,
      notes: notes,
      rich_text_content: script_notes,
      serial_code: serial(&:serial_code)
    }
  end

  belongs_to :network, optional: true
  belongs_to :serial, optional: true
  has_many :comments, as: :commentable, dependent: :destroy
  has_paper_trail

  extend FriendlyId
  friendly_id :pcode

  has_rich_text :historical_notes
  has_rich_text :script_notes
  has_one_attached :qc_video
  has_one_attached :feature_image
  has_many_attached :files

  enum state: {in_production: 0, airing: 1, paused: 2, cancelled: 3, pulled: 4, unused: 5, retired: 6}
  enum ptype: {episode: 0, program_set: 8, standalone_program: 1, announcement: 3, promotional: 2,  filler: 9, roll: 4, production_music: 5, audio_only: 6, other: 7}
  enum relationships: {standalone: 0, related: 1} #TODO: Get rid of this enum
  enum phase: { initiated: 0, prepped: 1, scheduled: 2, recorded: 3, edited: 4, reviewed: 5, delivered: 6, distributed: 7, archived: 8}

  validates_uniqueness_of :pcode
  validates :pcode, :year, :name, :network_id, presence: true
  validates :files, size: { less_than: 10.megabytes, message: 'is too large' }

  scope :ordered_by_pcode, -> { reorder(pcode: :desc) }
  scope :ordered_by_year, -> { reorder(year: :desc) }
  scope :been_recorded, -> { where.not(recorded_at: [nil,'']) }
  scope :search_by_pcode, -> (pcode) { where("(pcode::text LIKE ?)", "%#{pcode}%") }
  scope :for_year, -> year { where "year = ?", year }
  scope :for_network, -> (network_code) {includes(:network).where("network.code" => network_code)}

  class << self

    def next_pcode(year = Time.new.year)
      # PCodes are an integer that specially increments only the index starting after
      # the two digit year prefix; e.g. for year 2021: 211, 212 .. 218, 219, 2110, 2111
      max_pcode_for_year = Project.for_year(year).maximum('pcode')
      year_prefix = (year % 100) # Last two digits of year; e.g. "21" for 2021
      counter = max_pcode_for_year.nil? ? 1 : max_pcode_for_year.to_s[2..].to_i + 1
      (year_prefix.to_s << counter.to_s).to_i
    end

    # Usage: Project.recently_created(10)
    # h/t https://www.varvet.com/blog/retrieving-the-last-n-ordered-records-with-activerecord/
    def recently_created(n)
      in_order_of_created.endmost(n).reverse_order
    end

    def in_order_of_created
      order(created_at: :asc)
    end

    def in_order_of_recorded
      order(recorded_at: :asc)
    end

    def endmost(n)
      all.only(:order).from(all.reverse_order.limit(n), table_name)
    end

    def recently_recorded(n = 5)
      order('recorded_at DESC NULLS LAST').limit(n)
    end

    #   default_scope { order(pcode: :desc)}
    ## Instead:
    def sort_by_params(column, direction)
      sortable_column = sortable_columns.include?(column) ? column : "pcode"
      order(sortable_column => direction)
    end

  end # / << self (Class Methods)

  def next
    self.class.where("pcode > ?", pcode).order(pcode: :asc).first
  end

  def previous
    self.class.where("pcode < ?", pcode).order(pcode: :asc).last
  end

  def pcode_name
    if self.name
      self.pcode.to_s + " - " + self.name
    else
      self.pcode.to_s
    end
  end

  def current_dist_code
    return "#{dist_code}" if dist_code
    return "#{prov_dist_code} (P)" if prov_dist_code
  end

  private

    # Guard against project creation race conditions with PCode uniqueness
    def recheck_last_pcode
      self.pcode = Project.next_pcode(year) if self.pcode != Project.next_pcode(year)
    end

end

# TODO: Notes for implementing state columns, instead of current state enum : https://blog.vemv.net/the-status-antipattern-479c26c7ddf7
# validates :paid_at, inclusion: [nil], unless: :order_placed_at
# validates :delivered_at, inclusion: [nil], unless: :paid_at
# validates :refund_requested_at, inclusion: [nil], unless: :paid_at
# validates :refunded_at, inclusion: [nil], unless: :refund_requested_at
