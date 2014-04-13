# encoding: UTF-8

# $HeadURL$
# $Id$
#
# Copyright (c) 2009-2014 by Public Library of Science, a non-profit corporation
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

module Resolvable
  extend ActiveSupport::Concern

  included do

    def get_canonical_url(url, options = { timeout: 120 })
      conn = conn_html
      # disable ssl verification
      conn.options[:ssl] = { verify: false }

      conn.options[:timeout] = options[:timeout]
      response = conn.get url, {}, options[:headers]

      # Priority to find URL:
      # 1. <link rel=canonical />
      # 2. <meta property="og:url" />
      # 3. URL from header

      body = Nokogiri::HTML(response.body, nil, 'utf-8')
      body_url = body.at('link[rel="canonical"]')['href'] if body.at('link[rel="canonical"]')
      if !body_url && body.at('meta[property="og:url"]')
        body_url = body.at('meta[property="og:url"]')['content']
      end

      if body_url
        # remove percent encoding
        body_url = CGI.unescape(body_url)

        # make URL lowercase
        body_url = body_url.downcase

        # remove parameter used by IEEE
        body_url = body_url.sub("reload=true&", "")
      end

      url = response.env[:url].to_s
      if url
        # remove percent encoding
        url = CGI.unescape(url)

        # make URL lowercase
        url = url.downcase

        # remove jsessionid used by J2EE servers
        url = url.gsub(/(.*);jsessionid=.*/, '\1')

        # remove parameter used by IEEE
        url = url.sub("reload=true&", "")

        # remove parameter used by ScienceDirect
        url = url.sub("?via=ihub", "")
      end

      # get relative URL
      path = URI.split(url)[5]

      # we will raise an error if 1. or 2. doesn't match with 3. as this confuses Facebook
      if body_url.present? && ![url, path].include?(body_url)
        fail Faraday::Error::ClientError, "Canonical URL mismatch: #{body_url}"
      end

      url
    rescue *NETWORKABLE_EXCEPTIONS => e
      rescue_faraday_error(url, e, options.merge(doi_lookup: true))
    end

  end
end
