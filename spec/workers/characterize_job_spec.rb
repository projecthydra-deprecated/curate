require 'spec_helper'

describe CharacterizeJob do

  # I'm not entirely certain where I want to put this. Given that it is
  # leaning on an actor, I'd like to put it there. But actors are going to
  # push to a queue, so it is the worker that should choke.
  describe '#run' do
    let(:user) { FactoryGirl.create(:user) }
    let(:curation_concern) {
      GenericWork.new.tap(&:save)
    }
    let(:generic_file) {
      FactoryGirl.create_generic_file(curation_concern, user)
    }
    subject { CharacterizeJob.new(generic_file.pid) }

    it 'deletes the generic file when I upload a virus' do
      EnvironmentOverride.with_anti_virus_scanner(false) do
        expect {
          subject.run
        }.to raise_error(AntiVirusScanner::VirusDetected)
      end
    end
  end
end
