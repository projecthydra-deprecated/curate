module CurationConcern
  class GenericWorkActor < CurationConcern::BaseActor

    def create
      super && attach_files && create_linked_resources && download_create_cloud_resources && assign_representative
    end

    def update
      add_to_collections(attributes.delete(:collection_ids)) && super && attach_files && create_linked_resources
    end

    delegate :visibility_changed?, to: :curation_concern

    protected

    def files
      return @files if defined?(@files)
      @files = [attributes[:files]].flatten.compact
    end

    def attach_files
      files.all? do |file|
        attach_file(file)
      end
    end

    # The default behavior of active_fedora's has_and_belongs_to_many association,
    # when assigning the id accessor (e.g. collection_ids = ['foo:1']) is to add
    # to new collections, but not remove from old collections.
    # This method ensures it's removed from the old collections.
    def add_to_collections(new_collection_ids)
      return true if new_collection_ids.nil?
      #remove from old collections
      (curation_concern.collection_ids - new_collection_ids).each do |old_id|
        Collection.find(old_id).members.delete(curation_concern)
      end

      #add to new
      curation_concern.collection_ids = new_collection_ids
      true
    end

    def linked_resource_urls
      @linked_resource_urls ||= Array(attributes[:linked_resource_urls]).flatten.compact
    end

    def cloud_resources_urls
       logger.debug("Need to download from: #{attributes[:cloud_resource_urls].inspect}")
      @cloud_resource_urls ||= Array(attributes[:cloud_resource_urls]).split("|").flatten.compact
    end

    def download_create_cloud_resources
      logger.debug("Need to download from: #{cloud_resources_urls.inspect}")
      cloud_resources_urls.all? do |resource_url|
        attach_cloud_resource(resource_url)
      end
    end

    def attach_cloud_resource(download_url)
      return true if ! download_url.present?
      logger.debug("Need to download from: #{download_url.inspect}")
      #TODO Download the file and treat it as a attached file
       file_path=download_file_from_url(download_url)
       cloud_resource = File.open(file_path) if File.exists?(file_path)
      if cloud_resource
        generic_file = GenericFile.new
        generic_file.file = cloud_resource
        generic_file.batch = curation_concern
        Sufia::GenericFile::Actions.create_metadata(
            generic_file, user, curation_concern.pid
        )
        generic_file.embargo_release_date = curation_concern.embargo_release_date
        generic_file.visibility = visibility
        Sufia::GenericFile::Actions.create_content(
            generic_file,
            cloud_resource,
            File.basename(cloud_resource),
            'content',
            user
        )
        Sufia.queue.push(CharacterizeJob.new(generic_file.pid))
        File.delete(cloud_resource)
      end
    rescue ActiveFedora::RecordInvalid
      false
    end

    def download_file_from_url(url)
      destination_file_full_path = Rails.root.to_s + "/" + url.to_s.split("/").last
      logger.debug("Downloading to:#{destination_file_full_path}")
      begin
        open(destination_file_full_path, 'wb') do |file|
          file << open(URI.parse(url)).read if URI.parse(url.to_s)
        end
      rescue
        logger.error "Exception occured while downloading from cloud..."
      end
      destination_file_full_path
    end

    def create_linked_resources
      linked_resource_urls.all? do |link_resource_url|
        create_linked_resource(link_resource_url)
      end
    end

    def create_linked_resource(link_resource_url)
      return true if ! link_resource_url.present?
      resource = LinkedResource.new.tap do |link|
        link.url = link_resource_url
        link.batch = curation_concern
        link.label = curation_concern.human_readable_type
      end
      Sufia::GenericFile::Actions.create_metadata(resource, user, curation_concern.pid)
      true
    rescue ActiveFedora::RecordInvalid
      false
    end

    def assign_representative
      curation_concern.representative = curation_concern.generic_file_ids.first
      curation_concern.save
    end

    private
    def attach_file(file)
      generic_file = GenericFile.new
      generic_file.file = file
      generic_file.batch = curation_concern
      Sufia::GenericFile::Actions.create_metadata(
        generic_file, user, curation_concern.pid
      )
      generic_file.embargo_release_date = curation_concern.embargo_release_date
      generic_file.visibility = visibility
      CurationConcern.attach_file(generic_file, user, file)
    end
  end
end
