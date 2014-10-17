require 'spec_helper'

describe CurationConcern::GenericFilesController do
  let(:user) { FactoryGirl.create(:user) }
  let(:another_user) { FactoryGirl.create(:user) }
  let(:visibility) { Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE }
  let(:parent) {
    FactoryGirl.create_curation_concern(:generic_work, user, {visibility: visibility})
  }
  let(:file) { Rack::Test::UploadedFile.new(__FILE__, 'text/plain', false) }
  let(:generic_file) { FactoryGirl.create_generic_file(parent, user) {|gf|
      gf.visibility = visibility
    }
  }

  describe '#new' do
    it 'renders a form if you can edit the parent' do
      parent
      sign_in user
      get(:new, parent_id: parent.to_param)
      response.should be_successful
      expect(response).to render_template('new')
    end

    it 'redirects if you cannot edit the parent' do
      sign_in(another_user)
      parent
      expect {
        get :new, parent_id: parent.to_param
      }.to raise_rescue_response_type(:unauthorized)
    end
  end


  describe '#create' do
    let(:actor) { double('actor') }
    let(:actors_action) { :create }
    let(:failing_actor) {
      actor.should_receive(actors_action).and_return(false)
      actor
    }
    let(:successful_actor) {
      actor.should_receive(actors_action).and_return(true)
      actor
    }

    let(:client) { ClamAV.instance }

    it 'redirects to parent when successful' do
      sign_in(user)
      controller.actor = successful_actor

      post(
        :create,
        parent_id: parent.to_param,
        generic_file: { title: "Title", file: file }
      )
      expect(response).to(
        redirect_to(controller.polymorphic_path([:curation_concern, parent]))
      )
    end

    it 'should set represetative for parent' do

      CurationConcern::BaseActor.any_instance.stub(:apply_creation_data_to_curation_concern).and_return(true)
      CurationConcern::BaseActor.any_instance.stub(:apply_save_data_to_curation_concern).and_return(true)
      CurationConcern::GenericFileActor.any_instance.stub(:update_file).and_return(true)

      sign_in(user)
      parent.representative.should == nil

      image_file = File.expand_path('../../fixtures/files/image.png', __FILE__)
      post(
        :create,
        parent_id: parent.to_param,
        generic_file: { title: "Title", file: file }
      )

      expect(response).to(
        redirect_to(controller.polymorphic_path([:curation_concern, parent]))
      )

      reloaded_parent = GenericWork.find(parent.pid)
      reloaded_parent.representative.should_not == nil
    end

    it 'renders form when unsuccessful' do
      sign_in(user)
      controller.actor = failing_actor

      post(
        :create,
        parent_id: parent.to_param,
        generic_file: { title: "Title", file: file }
      )

      expect(response).to render_template('new')
      response.status.should == 422
    end

    it "should call virus check" do
      GenericFile.stub(:create).and_return({})
      test_file = File.expand_path('../../fixtures/files/image.png', __FILE__)
      client.loaddb()
      client.scanfile(test_file).should be_a_kind_of(Fixnum)
    end

  end

  describe '#edit' do
    it 'should be successful' do
      sign_in user
      get :edit, id: generic_file.to_param
      controller.curation_concern.should be_kind_of(GenericFile)
      response.should be_successful
    end
  end

  describe '#update' do
    let(:updated_title) { Time.now.to_s }
    let(:failing_actor) {
      actor.
      should_receive(:update).
      and_return(false)
      actor
    }
    let(:successful_actor) {
      actor.should_receive(:update).and_return(true)
      actor
    }
    let(:actor) { double('actor') }
    it 'renders form when unsuccessful' do
      controller.actor = failing_actor
      sign_in(user)
      put :update, id: generic_file.to_param, generic_file: {title: updated_title, file: file}
      expect(response).to render_template('edit')
      response.status.should == 422
    end

    it 'redirects to parent when successful' do
      controller.actor = successful_actor
      sign_in(user)
      put :update, id: generic_file.to_param, generic_file: {title: updated_title, file: file}
      response.status.should == 302
      expect(response).to(
        redirect_to(
          controller.polymorphic_path([:curation_concern, parent])
        )
      )
    end

  end


  describe '#versions' do
    it 'should be successful' do
      sign_in user
      get :versions, id: generic_file.to_param
      controller.curation_concern.should be_kind_of(GenericFile)
      response.should be_successful
    end
  end

  describe '#rollback' do
    let(:updated_title) { Time.now.to_s }
    let(:failing_actor) {
      actor.should_receive(:rollback).and_return(false)
      actor
    }
    let(:successful_actor) {
      actor.should_receive(:rollback).and_return(true)
      actor
    }
    let(:actor) { double('actor') }
    it 'renders form when unsuccessful' do
      controller.actor = failing_actor
      sign_in(user)
      put :rollback, id: generic_file.to_param, generic_file: {version: '1'}
      expect(response).to render_template('versions')
      response.status.should == 422
    end

    it 'redirects to generic_file when successful' do
      sign_in(user)
      controller.actor = successful_actor
      put :rollback, id: generic_file.to_param, generic_file: {version: '1'}
      response.status.should == 302
      expect(response).to(
        redirect_to(
          controller.polymorphic_path([:curation_concern, generic_file])
        )
      )
    end
  end

  describe '#show' do
    it 'should be successful if logged in' do
      sign_in user
      get :show, id: generic_file.to_param
      controller.curation_concern.should be_kind_of(GenericFile)
      response.should be_successful
    end

    it 'does not allow another user to view it' do
      sign_in another_user
      get :show, id: generic_file.to_param
      expect(response.status).to eq 401
      response.should render_template(:unauthorized)
    end
  end

  describe '#destroy' do
    it 'should be successful if file exists' do
      sign_in(user)
      delete :destroy, id: generic_file.to_param
      expect(response.status).to eq(302)
      expect(response).to redirect_to(controller.polymorphic_path([:curation_concern, generic_file.batch]))
    end
  end
end
