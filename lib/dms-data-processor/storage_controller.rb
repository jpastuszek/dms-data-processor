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

require 'set'

class RawDataKey
	module Path
		def method_missing(name, *args, &block)
			self.split('/').send(name, *args, &block)
		end
	end

	def self.[](location, path, component)
		self.new(location, path, component)
	end

	def initialize(location, path, component)
		@location = location
		@path = path.dup
		@path.extend Path
		@component = component
	end

	attr_reader :location
	attr_reader :path
	attr_reader :component

	def ==(rdk)
		@location == rdk.location and @path == rdk.path and @component == rdk.component
	end
end

class RawDatum
	def self.[](time_stamp, value)
		self.new(time_stamp, value)
	end

	def initialize(time_stamp, value)
		@time_stamp = DataType.to_time(time_stamp)
		@value = value
	end

	attr_reader :time_stamp
	attr_reader :value
end

class StorageController
	class Node < Hash
		def initialize
			super
			@callbacks = Set.new
		end

		def <<(callback)
			@callbacks << callback
		end

		attr_reader :callbacks
	end

	def initialize(storage)
		@storage = storage
		@notify_value_tree = {}
		@notify_components_tree = {}
	end

	def store(raw_data_key, raw_datum)
		new_component = ! @storage.fetch(raw_data_key.path, {}).fetch(raw_data_key.location, {}).has_key?(raw_data_key.component)

		@storage.store(raw_data_key, raw_datum)

		find_callbacks(raw_data_key.path.to_a, @notify_value_tree).each do |callback|
			callback[raw_data_key, raw_datum]
		end

		if new_component
			find_callbacks(raw_data_key.path.to_a, @notify_components_tree).each do |callback|
				tree = @storage[raw_data_key.path]

				components = Set.new
				tree.each_value do |location_node|
					location_node.each_value do |component_node|
						components.merge(component_node.keys)
					end
				end

				# TODO: it should be per location!
				# TODO: do I still need it like that?
				callback[raw_data_key.location, raw_data_key.path, components]
			end
		end
	end

	def [](prefix)
		@storage[prefix]
	end

	def fetch(path, default = :magick, &block)
		@storage.fetch(path, default, &block)
	end

	def notify_value(prefix, &callback)
		prefix = prefix.dup
		prefix.extend(RawDataKey::Path)
		make_nodes(prefix.to_a, @notify_value_tree) << callback
	end

	def notify_components(prefix, &callback)
		prefix = prefix.dup
		prefix.extend(RawDataKey::Path)
		make_nodes(prefix.to_a, @notify_components_tree) << callback
	end

	private

	# TODO: move to own class
	def find_callbacks(path_elements, root)
		callbacks = Set.new
		return callbacks if path_elements.empty?

		node = root[path_elements.shift]
		return callbacks unless node

		callbacks.merge(node.callbacks)
		callbacks.merge(find_callbacks(path_elements, node))

		callbacks
	end

	def make_nodes(path_elements, root)
		return root if path_elements.empty?
		make_nodes(path_elements, root[path_elements.shift] ||= Node.new)
	end
end

