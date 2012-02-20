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

shared_examples_for 'storage' do
	it 'should store value under component path and location' do
		subject.store('magi', 'system/CPU usage/cpu/0', 'idle', 12345)

		subject['system/CPU usage/cpu/0']['system/CPU usage/cpu/0']['magi']['idle'].to_a.should == [12345]
	end

	it 'should return nodes by path prefix' do
		subject.store('magi', 'system/CPU usage/cpu/0', 'idle', 12345)
		subject.store('magi', 'system/CPU usage/cpu/0', 'usage', 213)
		subject.store('magi', 'system/CPU usage/cpu/1', 'usage', 12)
		subject.store('nina', 'system/CPU usage/cpu/1', 'usage', 89)
		subject.store('nina', 'system/CPU usage/total', 'usage', 42)

		cpu = subject['system/CPU usage/cpu']
		cpu['system/CPU usage/cpu/0']['magi']['idle'].to_a.should == [12345]
		cpu['system/CPU usage/cpu/0']['magi']['usage'].to_a.should == [213]
		cpu['system/CPU usage/cpu/1']['magi']['usage'].to_a.should == [12]
		cpu['system/CPU usage/cpu/1']['nina']['usage'].to_a.should == [89]

		system = subject['system']
		system['system/CPU usage/cpu/0']['magi']['idle'].to_a.should == [12345]
		system['system/CPU usage/cpu/0']['magi']['usage'].to_a.should == [213]
		system['system/CPU usage/cpu/1']['magi']['usage'].to_a.should == [12]
		system['system/CPU usage/cpu/1']['nina']['usage'].to_a.should == [89]
		system['system/CPU usage/total']['nina']['usage'].to_a.should == [42]
	end

	it 'should store elements in fifo order' do
		subject.store('magi', 'system/CPU usage/cpu/0', 'idle', 1)
		subject.store('magi', 'system/CPU usage/cpu/0', 'idle', 2)
		subject.store('magi', 'system/CPU usage/cpu/0', 'idle', 3)

		system = subject['system']
		system['system/CPU usage/cpu/0']['magi']['idle'].to_a.should == [3, 2, 1]
	end
end

