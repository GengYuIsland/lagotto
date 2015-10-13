class ArticleCoverageCurated < Agent
  # include common methods for Article Coverage
  include Coverable

  def get_related_works(result, work)
    Array(result.fetch('referrals', nil)).map do |item|
      timestamp = get_iso8601_from_time(item.fetch('published_on', nil))
      type = item.fetch("type", nil)
      type = MEDIACURATION_TYPE_TRANSLATIONS.fetch(type, nil) if type
      url = item.fetch('referral', nil)

      {
        "pid" => url,
        "author" => nil,
        "title" => item.fetch("title", ""),
        "container-title" => item.fetch("publication", ""),
        "issued" => get_date_parts(timestamp),
        "timestamp" => timestamp,
        "URL" => url,
        "type" => type,
        "tracked" => true,
        "related_works" => [{ "pid" => work.pid,
                              "source_id" => name,
                              "relation_type_id" => "discusses" }] }
    end
  end

  def get_extra(result)
    Array(result.fetch('referrals', nil)).map do |item|
      event_time = get_iso8601_from_time(item['published_on'])
      url = item['referral']
      type = item.fetch("type", nil)
      type = MEDIACURATION_TYPE_TRANSLATIONS.fetch(type, nil) if type

      { event: item,
        event_time: event_time,
        event_url: url,

        # the rest is CSL (citation style language)
        event_csl: {
          'author' => '',
          'title' => item.fetch('title') { '' },
          'container-title' => item.fetch('publication') { '' },
          'issued' => get_date_parts(event_time),
          'url' => url,
          'type' => type }
        }
    end
  end
end
