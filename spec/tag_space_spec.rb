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

describe TagSpace do
	subject do
		ts = TagSpace.new
		ts[Tag.new('System:memory')] = 1
		ts[Tag.new('java:memory')] = 2
		ts[Tag.new('java:memory:heap:PermGenSpace')] = 3
		ts[Tag.new('java:memory:heap:EdenSpace')] = 4
		ts[Tag.new('location:magi')] = 3
		ts[Tag.new('location:nina')] = 4
		ts[Tag.new('bingo')] = 4
		ts[Tag.new('bingo')] = 2
		ts
	end

	it 'should string as a tag' do
		subject['stringi'] = 9
		subject[TagExpression.new('stringi')].sort.should == [9]
	end

	describe '#[]' do
		context 'tag string matching' do
			it 'should work for strings representing patterns and expressions' do
				subject['system'].sort.should == [1]
				subject['java:memory:heap:PermGenSpace'].sort.should == [3]
				subject['heap:/space/, bingo'].sort.should == [4]
			end
		end

		context 'tag pattern matching' do
			it 'should provide values for single tag word pattern' do
				subject[TagPattern.new('system')].sort.should == [1]
				subject[TagPattern.new('Memory')].sort.should == [1, 2, 3, 4]
				subject[TagPattern.new('java')].sort.should == [2, 3, 4]
				subject[TagPattern.new('heap')].sort.should == [3, 4]
				subject[TagPattern.new('permgenspace')].sort.should == [3]
			end

			it 'should provide values for multi level tag pattern' do
				subject[TagPattern.new('java:memory:heap:PermGenSpace')].sort.should == [3]
				subject[TagPattern.new('java:memory:heap:EdenSpace')].sort.should == [4]

				subject[TagPattern.new('memory:heap:PermGenSpace')].sort.should == [3]
				subject[TagPattern.new('memory:heap:EdenSpace')].sort.should == [4]

				subject[TagPattern.new('memory:heap')].sort.should == [3, 4]
				subject[TagPattern.new('system:memory')].sort.should == [1]
			end
			
			it 'should provide values for patterns including regexp' do
				subject[TagPattern.new('/sys/:/mem/')].sort.should == [1]
				subject[TagPattern.new('/mem/')].sort.should == [1, 2, 3, 4]
				subject[TagPattern.new('java:/mem/')].sort.should == [2, 3, 4]


				subject[TagPattern.new('heap:/space/')].sort.should == [3, 4]
				subject[TagPattern.new('//')].sort.should == [1, 2, 3, 4]
			end

			it 'should return empty array if there was no match' do
				subject[TagPattern.new('heap:java')].should be_empty
				subject[TagPattern.new('memory://:heap')].should be_empty
				subject[TagPattern.new('test')].should be_empty
				subject[TagPattern.new('')].should be_empty
			end
		end

		context 'tag expression matching' do
			it 'should return all values that are matched by all tag patterns' do
				subject[TagExpression.new('heap:/space/, /perm/')].sort.should == [3]
				subject[TagExpression.new('heap:/space/, /eden/')].sort.should == [4]
				subject[TagExpression.new('heap:/space/, /eden/, memory')].sort.should == [4]

				subject[TagExpression.new('heap:/space/, location:/magi/')].sort.should == [3]
				subject[TagExpression.new('heap:/space/, location:/nina/')].sort.should == [4]
				subject[TagExpression.new('memory, magi')].sort.should == [3]

				subject[TagExpression.new('memory')].sort.should == [1, 2, 3, 4]
				subject[TagExpression.new('bingo')].sort.should == [2, 4]

				subject[TagExpression.new('bingo, nina')].sort.should == [4]
				subject[TagExpression.new('bingo, memory')].sort.should == [2, 4]
				subject[TagExpression.new('heap:/space/, bingo')].sort.should == [4]

				subject[TagExpression.new('bingo, magi')].should be_empty
				subject[TagExpression.new('bingo, system')].should be_empty
			end
		end
	end
end

