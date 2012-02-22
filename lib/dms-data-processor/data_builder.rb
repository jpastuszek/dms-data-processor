# Copyright (c) 2012 Jakub Pastuszek
#
# This file is part of Distributed Monitoring System.
#
# Distributed Monitoring System is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Distributed Monitoring System is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Distributed Monitoring System.  If not, see <http://www.gnu.org/licenses/>.

require 'dms-data-processor/data_type'
require 'set'

class DataBuilder
	include DSL

	def initialize(data_type, tag_space, storage_controller, &block)
		@data_type = data_type
		@tag_space = tag_space
		@storage_controller = storage_controller

		@tags = Set.new
		@new_tags = Set.new
		dsl_method :tag do |tag|
			@new_tags << tag
		end

		@needed_components = Set.new
		dsl_method :component do |name|
			@needed_components << name
		end

		@available_paths = Set.new

		dsl_method :prefix do |prefix, &block|
			log.debug "#{data_type.name}: uses raw data under prefix: #{prefix}"

			if log.debug? 
				@storage_controller.notify_value(prefix) do |location, path, component, value|
					log.debug "[#{prefix}]#{path[prefix.length..-1]}: stored '#{component}': #{value}"
				end
			end

			@storage_controller.notify_components(prefix) do |location, path, stored_components|
				next if @available_paths.include?([prefix, path])

				if stored_components.superset?(@needed_components)
					@available_paths << [prefix, path]
					block.call(location, path, stored_components)
					flush_tags
				end
			end
		end

		dsl_method :data do
		end

		dsl(&block)

		log.debug "#{data_type.name}: needs components: #{@needed_components.to_a} to produce data"
	end

	attr_reader :data_type
	attr_reader :tags

	private

	def flush_tags
		tags = @new_tags - @tags
		return if tags.empty?

		log.info "'#{data_type.name}' data set is available under new tags: #{tags.to_a.sort.join(', ')}"
		tags.each do |tag|
			@tag_space[tag] = self
		end

		@tags.merge(tags)
		@new_tags.clear
	end
end

