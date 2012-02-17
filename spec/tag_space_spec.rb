require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TagSpace do
	describe '#[]' do
		subject do
			ts = TagSpace.new
			ts['System:memory'] = 1
			ts['java:memory'] = 2
			ts['java:memory:heap:PermGenSpace'] = 3
			ts['java:memory:heap:EdenSpace'] = 4
			ts
		end

		it 'should provide values for single tag word pattern' do
			subject['system'].sort.should == [1]
			subject['Memory'].sort.should == [1, 2, 3, 4]
			subject['java'].sort.should == [2, 3, 4]
			subject['heap'].sort.should == [3, 4]
			subject['permgenspace'].sort.should == [3]
		end

		it 'should provide values for multi level tag pattern' do
			subject['java:memory:heap:PermGenSpace'].sort.should == [3]
			subject['java:memory:heap:EdenSpace'].sort.should == [4]

			subject['memory:heap:PermGenSpace'].sort.should == [3]
			subject['memory:heap:EdenSpace'].sort.should == [4]

			subject['memory:heap'].sort.should == [3, 4]
			subject['system:memory'].sort.should == [1]
		end
		
		it 'should provide values for patterns including regexp' do
			subject['/sys/:/mem/'].sort.should == [1]
			subject['/mem/'].sort.should == [1, 2, 3, 4]
			subject['java:/mem/'].sort.should == [2, 3, 4]


			subject['heap:/space/'].sort.should == [3, 4]
			subject['//'].sort.should == [1, 2, 3, 4]
		end

		it 'should return empty array if there was no match' do
			subject['heap:java'].should be_empty
			subject['memory://:heap'].should be_empty
			subject['test'].should be_empty
			subject[''].should be_empty
		end
	end
end

