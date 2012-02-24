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

Infinity = 1.0 / 0 unless defined?(Infinity)

class DataType
	include DSL

	def initialize(name, &block)
		@name = name
		dsl_variable :unit
		dsl_variable :range, -Infinity...Infinity
		dsl &block
	end

	attr_reader :name
	attr_reader :range
	attr_reader :unit

	def to_s
		"DataType[#{@name}: #{@unit}]"
	end
end

