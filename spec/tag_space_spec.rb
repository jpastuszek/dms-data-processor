require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TagSpace do
	subject do
		TagSpace.new
	end

	it 'should store custom object under a tag and retrive it by tag pattern' do
		subject['System:memory'] = :hello_world

		subject['Memory'].should == [:hello_world]
		subject['system'].should == [:hello_world]
		subject['/sys/:/mem/'].should == [:hello_world]

		subject['java:memory'] = 42
		subject['Memory'].should include(:hello_world)
		subject['Memory'].should include(42)

		#subject['java'].should == [42]
	end
end

