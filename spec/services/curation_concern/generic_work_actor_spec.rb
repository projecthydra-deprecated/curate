require 'spec_helper'

describe CurationConcern::GenericWorkActor do
  include ActionDispatch::TestProcess
  let(:user) { FactoryGirl.create(:user) }
  let(:file) { curate_fixture_file_upload('files/image.png', 'image/png') }

  subject {
    CurationConcern.actor(curation_concern, user, attributes)
  }

  describe '#create' do

    let(:curation_concern) { GenericWork.new(pid: CurationConcern.mint_a_pid )}

    describe 'valid attributes' do
      let(:visibility) { Sufia::Models::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED }

      describe 'with a file' do
        let(:attributes) {
          FactoryGirl.attributes_for(:generic_work, visibility: visibility).tap {|a|
            a[:files] = file
          }
        }
        before(:each) do
          subject.create!
        end

        describe 'authenticated visibility' do
          it 'should stamp each file with the access rights' do
            expect(curation_concern).to be_persisted
            curation_concern.date_uploaded.should == Date.today
            curation_concern.date_modified.should == Date.today
            curation_concern.depositor.should == user.user_key

            curation_concern.generic_files.count.should == 1
            # Sanity test to make sure the file we uploaded is stored and has same permission as parent.
            generic_file = curation_concern.generic_files.first
            expect(generic_file.content.content).to eq file.read
            expect(generic_file.filename).to eq 'image.png'

            expect(curation_concern).to be_authenticated_only_access
            expect(generic_file).to be_authenticated_only_access
          end
        end
      end

      describe 'with multiple files file' do
        let(:attributes) {
          FactoryGirl.attributes_for(:generic_work, visibility: visibility).tap {|a|
            a[:files] = [file, file]
          }
        }
        before(:each) do
          subject.create!
        end

        describe 'authenticated visibility' do
          it 'should stamp each file with the access rights' do
            expect(curation_concern).to be_persisted
            curation_concern.date_uploaded.should == Date.today
            curation_concern.date_modified.should == Date.today
            curation_concern.depositor.should == user.user_key

            curation_concern.generic_files.count.should == 2
            # Sanity test to make sure the file we uploaded is stored and has same permission as parent.

            expect(curation_concern).to be_authenticated_only_access
          end
        end
      end

      describe 'with a linked resource' do
        let(:attributes) {
          FactoryGirl.attributes_for(:generic_work, visibility: visibility, linked_resource_url: 'http://www.youtube.com/watch?v=oHg5SJYRHA0')
        }
        before(:each) do
          subject.create!
        end

        describe 'authenticated visibility' do
          it 'should stamp each link with the access rights' do
            expect(curation_concern).to be_persisted
            curation_concern.date_uploaded.should == Date.today
            curation_concern.date_modified.should == Date.today
            curation_concern.depositor.should == user.user_key

            curation_concern.generic_files.count.should == 0
            curation_concern.linked_resources.count.should == 1
            # Sanity test to make sure the file we uploaded is stored and has same permission as parent.
            link = curation_concern.linked_resources.first
            expect(link.url).to eq 'http://www.youtube.com/watch?v=oHg5SJYRHA0'
            expect(curation_concern).to be_authenticated_only_access
          end
        end
      end
    end

    describe '#update' do
      let(:curation_concern) { FactoryGirl.create(:generic_work, user: user)}
      describe 'adding to collections' do
        let!(:collection1) { FactoryGirl.create(:collection, user: user) }
        let!(:collection2) { FactoryGirl.create(:collection, user: user) }
        let(:attributes) {
          FactoryGirl.attributes_for(:generic_work,
                                     visibility: Sufia::Models::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC,
                                     collection_ids: [collection2.pid])
        }
        before do
          curation_concern.apply_depositor_metadata(user.user_key)
          curation_concern.save!
          collection1.members << curation_concern
          collection1.save
        end
        it "should add to collections" do
          collection1.save # Had to call .save again to make this persist properly!? - MZ Sept 2013
          expect(curation_concern.collections).to eq [collection1]
          subject.update!
          expect(curation_concern.identifier).to be_blank
          expect(curation_concern).to be_persisted
          expect(curation_concern).to be_open_access
          expect(curation_concern.collections).to eq [collection2]
          expect(subject.visibility_changed?).to be_true
        end
      end
    end
  end
end
