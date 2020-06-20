require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command::Code do
    describe 'CLAide' do
      it 'registers it self' do
        Command.parse(%w{ Code }).should.be.instance_of Command::Code
      end
    end
  end
end

