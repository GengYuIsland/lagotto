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

module Measurable
  extend ActiveSupport::Concern

  included do

    # create a hash with the different metrics categories
    # total is sum of all categories if no total value is provided
    def get_metrics(options = {})
      options[:total] ||= options.values.inject(0) { |sum, v| sum + v.as_i }

      { :pdf => options[:pdf],
        :html => options[:html],
        :shares => options[:shares],
        :groups => options[:groups],
        :comments => options[:comments],
        :likes => options[:likes],
        :citations => options[:citations],
        :total => options[:total] }
    end

  end
end
