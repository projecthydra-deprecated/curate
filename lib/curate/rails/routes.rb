module ActionDispatch::Routing
  class Mapper

    def curate_for(opts={})
      scope module: 'curate' do
        resources 'collections' do
          collection do
            get :add_member_form
            put :add_member
          end
        end
        resources 'people', only: [:show, :index] do
          resources :depositors, only: [:index, :create, :destroy]
        end
      end
      resources :downloads, only: [:show]

      namespace :curation_concern, path: :concern do
        opts[:containers].each do |container|
          resources container, except: [:index]
        end
        resources( :permissions, only:[]) do
          member do
            get :confirm
            post :copy
          end
        end
        resources( :linked_resources, only: [:new, :create], path: 'container/:parent_id/linked_resources')
        resources( :linked_resources, only: [:show, :edit, :update, :destroy])
        resources( :generic_files, only: [:new, :create], path: 'container/:parent_id/generic_files')
        resources( :generic_files, only: [:show, :edit, :update, :destroy]) do
          member do
            get :versions
            put :rollback
          end
        end
      end

      resources :terms_of_service_agreements, only: [:new, :create]
      resources :help_requests, only: [:new, :create]
      resources :classify_concerns, only: [:new, :create]

      match "show/:id" => "common_objects#show", via: :get, as: "common_object"
      match "show/stub/:id" => "common_objects#show_stub_information", via: :get, as: "common_object_stub_information"
    end
  end
end
