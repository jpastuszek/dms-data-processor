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
require 'storage'

describe StorageController do
	subject do
		StorageController.new(MemoryStorage.new(100))
	end

	it_behaves_like 'storage'

	it 'should call a callback on storage of objects under matching prefix' do
		notices = []
		subject.notify('system') do |location, path, component, value|
			notices << [1, location, path, component, value]
		end

		subject.notify('system/CPU usage/cpu/0') do |location, path, component, value|
			notices << [2, location, path, component, value]
		end

		subject.notify('system/bogous') do |location, path, component, value|
			notices << [3, location, path, component, value]
		end

		subject.notify('jmx/tomcat') do |location, path, component, value|
			notices << [4, location, path, component, value]
		end

		subject.store('magi', 'system/CPU usage/cpu/0', 'usage', 213)
		notices.should have(2).notices
		notices.shift.should == [1, 'magi', 'system/CPU usage/cpu/0', 'usage', 213]
		notices.shift.should == [2, 'magi', 'system/CPU usage/cpu/0', 'usage', 213]

		subject.store('nina', 'system/CPU usage/cpu/1', 'idle', 123)
		notices.should have(1).notices
		notices.shift.should == [1, 'nina', 'system/CPU usage/cpu/1', 'idle', 123]

		subject.store('nina', 'jmx/tomcat/test', 'idle', 123)
		notices.should have(1).notices
		notices.shift.should == [4, 'nina', 'jmx/tomcat/test', 'idle', 123]

		subject.store('nina', 'jmx/tomc', 'idle', 123)
		notices.should have(0).notices

		subject.store('nina', 'tomcat', 'idle', 123)
		notices.should have(0).notices

		subject.store('nina', 'jmx', 'idle', 123)
		notices.should have(0).notices
	end
end

