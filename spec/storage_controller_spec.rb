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

	it 'should notify on stored value under given prefix' do
		notices = []
		subject.notify_value('system') do |location, path, component, value|
			notices << [1, location, path, component, value]
		end

		subject.notify_value('system/CPU usage/cpu/0') do |location, path, component, value|
			notices << [2, location, path, component, value]
		end

		subject.notify_value('system/bogous') do |location, path, component, value|
			notices << [3, location, path, component, value]
		end

		subject.notify_value('jmx/tomcat') do |location, path, component, value|
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

	it 'should notify when new component is stored under given path prefix' do
		notices = []
		subject.notify_components('system') do |location, path, components|
			notices << [1, location, path, components]
		end

		subject.notify_components('system/CPU usage/cpu/0') do |location, path, components|
			notices << [2, location, path, components]
		end

		subject.notify_components('system/bogous') do |location, path, components|
			notices << [3, location, path, components]
		end

		subject.notify_components('jmx/tomcat') do |location, path, components|
			notices << [4, location, path, components]
		end

		subject.store('magi', 'system/CPU usage/cpu/0', 'usage', 213)
		notices.should have(2).notices
		notices.shift.should == [1, 'magi', 'system/CPU usage/cpu/0', Set['usage']]
		notices.shift.should == [2, 'magi', 'system/CPU usage/cpu/0', Set['usage']]

		subject.store('magi', 'system/CPU usage/cpu/0', 'idle', 213)
		notices.should have(2).notices
		notices.shift.should == [1, 'magi', 'system/CPU usage/cpu/0', Set['usage', 'idle']]
		notices.shift.should == [2, 'magi', 'system/CPU usage/cpu/0', Set['usage', 'idle']]

		subject.store('nina', 'system/CPU usage/cpu/1', 'idle', 123)
		notices.should have(1).notices
		notices.shift.should == [1, 'nina', 'system/CPU usage/cpu/1', Set['idle']]

		subject.store('nina', 'system/CPU usage/cpu/1', 'usage', 123)
		notices.should have(1).notices
		notices.shift.should == [1, 'nina', 'system/CPU usage/cpu/1', Set['idle', 'usage']]

		subject.store('nina', 'jmx/tomcat/test', 'idle', 123)
		notices.should have(1).notices
		notices.shift.should == [4, 'nina', 'jmx/tomcat/test', Set['idle']]

		subject.store('nina', 'jmx/tomc', 'idle', 123)
		notices.should have(0).notices

		subject.store('nina', 'tomcat', 'idle', 123)
		notices.should have(0).notices

		subject.store('nina', 'jmx', 'idle', 123)
		notices.should have(0).notices
	end
end

