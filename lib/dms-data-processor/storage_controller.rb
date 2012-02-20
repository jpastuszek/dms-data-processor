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
		@notify_tree = {}
	end

	def store(location, path, component, value)
		@storage.store(location, path, component, value)

		find_callbacks(path.split('/')).each do |callback|
			callback[location, path, component, value]
		end
	end

	def [](prefix)
		@storage[prefix]
	end

	def notify(prefix, &callback)
		make_nodes(prefix.split('/')) << callback
	end

	private

	def find_callbacks(path_elements, root = @notify_tree)
		callbacks = Set.new
		return callbacks if path_elements.empty?

		node = root[path_elements.shift]
		return callbacks unless node

		callbacks.merge(node.callbacks)
		callbacks.merge(find_callbacks(path_elements, node))

		callbacks
	end

	def make_nodes(path_elements, root = @notify_tree)
		return root if path_elements.empty?
		make_nodes(path_elements, root[path_elements.shift] ||= Node.new)
	end
end

