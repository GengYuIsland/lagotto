# $HeadURL$
# $Id$
#
# Copyright (c) 2009-2012 by Public Library of Science, a non-profit corporation
# http://www.plos.org/
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

class RetrievalStatus < ActiveRecord::Base
  # include HTTP request helpers
  include Networkable

  # include CouchDB helpers
  include Couchable

  belongs_to :article, :touch => true
  belongs_to :source
  has_many :retrieval_histories, :dependent => :destroy

  before_destroy :delete_couchdb_document

  serialize :event_metrics

  delegate :name, :to => :source
  delegate :display_name, :to => :source
  delegate :group, :to => :source

  scope :most_cited, lambda { where("event_count > ?", 0).order("event_count desc").limit(25) }
  scope :most_cited_last_x_days, lambda { |duration| joins(:article).where("event_count > ?", 0).where("articles.published_on >= ?", Date.today - duration.days).order("event_count desc").limit(25) }
  scope :most_cited_last_x_months, lambda { |duration| joins(:article).where("event_count > ?", 0).where("articles.published_on >= ?", Date.today - duration.months).order("event_count desc").limit(25) }

  scope :queued, where("queued_at is NOT NULL")
  scope :not_queued, where("queued_at is NULL")
  scope :stale, where("queued_at is NULL").where("scheduled_at IS NOT NULL").where("scheduled_at <= ?", Time.zone.now).order("scheduled_at")
  scope :published, joins(:article).where("queued_at is NULL").where("articles.published_on <= ?", Date.today)
  scope :with_sources, joins(:source).where("sources.state > ?", 0).order("group_id, display_name")

  scope :total, lambda { |duration| where("retrieved_at > ?", Time.zone.now - duration.days) }
  scope :with_events, lambda { |duration| where("event_count > ?", 0).where("retrieved_at > ?", Time.zone.now - duration.days) }
  scope :without_events, lambda { |duration| where("event_count = ?", 0).where("retrieved_at > ?", Time.zone.now - duration.days) }

  scope :by_source, lambda { |source_ids| where(:source_id => source_ids) }
  scope :by_name, lambda { |source| includes(:source).where("sources.name = ?", source) }

  def data
    if event_count > 0
      data = get_alm_data("#{source.name}:#{article.uid_escaped}")
    else
      nil
    end
  end

  def events
    if data.blank? || data["error"]
      []
    else
      data["events"]
    end
  end

  def metrics
    unless data.blank?
      data["event_metrics"]
    else
      []
    end
  end

  def delete_document
    unless data_rev.nil
      document_id = "#{source.name}:#{article.uid_escaped}"
      remove_alm_data(document_id, data_rev)
    else
      nil
    end
  end

  # calculate datetime when retrieval_status should be updated, adding random interval
  # sources that are not queueable use a fixed date
  def stale_at
    unless source.queueable
      cron_parser = CronParser.new(source.cron_line)
      return cron_parser.next(Time.zone.now)
    end

    if article.published_on.present?
      age_in_days = Date.today - article.published_on
    else
      age_in_days = 366
    end

    if age_in_days < 0
      article.published_on
    elsif (0..7).include?(age_in_days)
      random_time(source.staleness[0])
    elsif (8..31).include?(age_in_days)
      random_time(source.staleness[1])
    elsif (32..365).include?(age_in_days)
      random_time(source.staleness[2])
    else
      random_time(source.staleness.last)
    end
  end

  def random_time(duration)
    Time.zone.now + duration + rand(duration/10)
  end

  private

  def delete_couchdb_document
    couchdb_id = "#{source.name}:#{article.uid_escaped}"
    data_rev = get_alm_rev(couchdb_id)
    remove_alm_data(couchdb_id, data_rev)
  end
end
