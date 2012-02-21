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

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe DataType do
	it 'should take and provide name' do
		DataType.new('CPU usage').name.should == 'CPU usage'
	end

	it 'should take block where unit can be defined' do
		DataType.new('CPU usage').unit.should == nil

		DataType.new('CPU usage') do
			unit '%'
		end.unit.should == '%'
	end

	it 'should take block where range can be defined (including Infinity)' do
		DataType.new('CPU usage').range.should == (-Infinity...Infinity)

		DataType.new('CPU usage') do
			range 0...Infinity
		end.range.should == (0...Infinity)

		DataType.new('CPU usage') do
			range -Infinity...100
		end.range.should == (-Infinity...100)
	end
end

