class Shrine
  module Plugins
    # An experiment in a derivatives plugin, that right now is really messy.
    #
    # Derivatives are stored in a separate column. For this demo, the separate column does have
    # an attacher, which needs the legacy :versions plugin on it. If we kept this architecture,
    # we'd make a new plugin, based off :versions, which did exactly what was needed no more no less.
    #
    # The derivatives plugin itself
    # will assume this separate attribute is at eg `avatar_derivatives[_data]`. But you can specify
    # another one with option :attribute.
    #
    #      class AvatarUploader < Shrine
    #        plugin :derivatives
    #      end
    #
    #      class User < ActiveRecord::Base
    #        include FileSetUploader::Attachment.new(:asset)
    #
    #        # Hypothetically you could use a custom one to customize behavior?
    #        include Shrine::Plugins::Derivatives::BasicContainerUploader::Attachment.new(:asset_derivatives)
    #      end
    #
    # The way you add derivatives is with `update_derivatives`, currently off the main attacher:
    #
    #     user.avatar_attacher.update_derivatives(thumb: io1, big_thumb: io2)
    #
    # This will immediately persist to db (if using an ORM), also saving any other in-memory changes you
    # happened to have on the model, ideally in a race-condition-safe
    # way. If you use the Derivatives::UpdateStrategies::ActiveRecord::PessimisticLockMerge,
    # it should hypothetically be race-condition-safe. (Although I'm worried what happens if you do
    # `update_derivatives` already inside a transaction, like it would be in a before_save or after_save
    # callback).  There is also a Derivatives::UpdateStrategies::Swap, which is definitely not
    # race-condition-safe. You can for now set the strategy with
    # `plugin :derivatives, update_strategy: Derivatives::UpdateStrategies::ActiveRecord::PessimisticLockMerge`
    #
    # Derivatives are by default persisted to your `:store` (without a two-step save, right to :store),
    # but you can pick whatever storage key you want with `plugin :derivatives, storage_key: :derivatives_store`.
    #
    # The idea is that you can call update_derivatives whenever, to have the exact order of operations
    # you want. In the most basic case, you might just want to do it as part of the shrine ingest process...
    # maybe in a shrine `after_store` hook? I haven't really tested that. It would be an ADDITIONAL
    # save in the best case (so a third save for shrine promotion :( ).  Or you could do it in a background
    # job of your own or a controller, with no coordination with shrine. (Still an extra save obviously).
    #
    # You access derivatives the same way you did versions (becuase in fact it is currently implemented
    # by versions):
    #
    #     user.avatar_derivatives[:thumb] #=> UploadedFile, or nil.
    #
    # Things I personally want to do that this doens't even handle yet include: pretty locations
    # for derivatives; being able to at least explicitly set explicitly specified metadata on
    # derivatives. Also specifying an alternate storage key
    module Derivatives

      def self.configure(uploader, options = {})
        options[:storage_key] ||= :store

        uploader.opts[:derivatives] = options
      end

      module AttacherMethods

        # Override assign, so a new original will clear out any existing derivatives.
        # Not sure how well this will work wrt to race conditions etc.
        # def assign(*)
        #   super
        #   derivatives_attacher.assign(nil)
        # end


        # pass a hash with symbol (or string) keys and io objects.
        # Will SAVE your model. if there are any other unsaved changes in your model, they
        # will get persisted to disk too. SHOULD be race-condition-safe with an ORM-dependent update strategy,
        # but the default Swap strategy is NOT.
        # Currently no way to REMOVE derivatives.
        # Currently no way to specify metadata (and I jrochkind really want/need deriv-specific metadata)
        def update_derivatives(new_derivatives_hash)
          created_derivatives = create_derivatives(new_derivatives_hash)
          update_derivatives_with_strategy(derivatives_attacher: derivatives_attacher,
                                           merge_values: created_derivatives).tap do |success, replaced_derivs|
            if success && replaced_derivs
              # the 'versions' plugin handles the fact that this may be a nested hash
              require 'byebug'
              byebug if $jdebug
              derivatives_uploader.delete(replaced_derivs)
            else
              # we did not succesfully persist them to model, so delete the actual files from store too please
              derivatives_uploader.delete(created_derivatives)
            end
          end
        end

        # Takes a hash (possibly nested jsonable) of IOs, converts it to a hash of UploadedFiles
        def create_derivatives(new_derivatives)
          # IS extracting metadata, for better or worse. doesn't succeed in extracting much
          # without a plugin.
          derivatives_uploader.upload(new_derivatives, action: :derivatives)
        end

        private

        def derivatives_uploader
          derivatives_attacher.shrine_class.new(shrine_class.opts[:derivatives][:storage_key])
        end

        # Tries to use one of a number of strategies to update with derivatives changes
        # minimizing or eliminating race conditions.
        #
        # All of these strategies (but ModelOnly!) persist the change to db if succesful.
        # Some of them do NOT show the change in the in-memory model you may need to reload
        # to see it.
        #
        # TODO, list of altered columsn needs to be returned from strategy, can't count on
        # one we got ourselves!
        #
        # Returns true or false depending on whether it succeeded -- if it didn't, the caller
        # probably wants to delete the new derivatives UploadedFiles that were not succesfully
        # saved to model.
        def update_derivatives_with_strategy(derivatives_attacher:, merge_values:, strategy: nil)
          strategy ||= shrine_class.opts[:derivatives][:update_strategy] || UpdateStrategies::Swap
          strategy.call(original_attacher: self, derivatives_attacher: derivatives_attacher, merge_values: merge_values)
        end

        def derivatives_attacher
          @derivatives_attribute ||= shrine_class.opts[:derivatives][:attribute] || "#{name}_derivatives"

          record.send("#{@derivatives_attribute}_attacher")
        end
      end

      BasicContainerUploader = Class.new(Shrine) do
        plugin :versions
      end

      # just a collection of 'static' methods, module constants is a convenient place to leave them,
      # organized in namespaces. Each method is
      #     call(original_attacher:, derivatives_attacher:, merge_values)
      #
      # Where merge_values is a hash (possibly nested) whose ultimate values are FileUploads
      # and returns
      #      [success_flag, replaced_derivatives_hash]
      #
      #  replaced_derivatives_hash is a symbol-keyed hash whose values are FileUploads (possibly nested)
      module UpdateStrategies

        # uses the already existing #swap method, which is overridden backgrounding plugin to try
        # and be semi-race condition safe, but that override won't be active here, we know it
        # isn't completely safe anyway for what it was intended, and the fact that there are now
        # TWO columns it would need to worry about would make it even less effective.
        #
        # So this is definitley NOT race condition safe, at all.
        #
        # It DOES immediately save record, since swap calls update.
        #
        # It DOES pass basic test, which shows basic test is not suitable for avoiding race condition.
        module Swap
          def self.call(original_attacher:, derivatives_attacher:, merge_values:)
            derivatives_attacher.swap( (derivatives_attacher.get || {}).merge(merge_values) )
          end
        end

        module ActiveRecord

          # If there are any unsaved changes in your model, they are going to end up saved.
          # Best is not to do this when there might be.
          # Should be totally race-condition safe, we think.
          module PessimisticLockMerge
            def self.call(original_attacher:, derivatives_attacher:, merge_values:)
              record             = original_attacher.record
              derivatives_column = derivatives_attacher.data_attribute
              original_column    = original_attacher.data_attribute

              # What if we're already IN a transaction cause we try doing this in a before/after save
              # or something? Not sure if that's going to ruin the semantics and/or
              record.class.transaction do
                # AR 'pluck' might be more targetted, but made everything a lot harder.
                #
                # Also throughout shrine it should probably use AR primary_key introspection instead
                # of assuming `id`.
                current_record_state = record.class.where(id: record.id).lock.first
                current_derivatives = current_record_state.send(derivatives_attacher.name) || {}

                if current_record_state.send("#{original_attacher.name}_attacher").read != original_attacher.read
                  # if original has changed, we're not adding anything, failure to update.
                  return false
                end
                byebug if $jdebug
                replaced_derivs = current_derivatives.select {|k| merge_values.keys.include?(k.to_s) || merge_values.keys.include?(k.to_sym) }

                new_derivatives = current_derivatives.merge(merge_values)

                # Dev note: private _set method, bad.
                require 'byebug'
                byebug if $jdebug
                derivatives_attacher.send(:_set, new_derivatives)

                record.save!

                return [true, replaced_derivs]
              end
            end
          end

          # If you already are using AR OptimisticLocking on the model anwyay, the PessimisticLockMerge
          # won't be able to recover from a lock failure. This one will, at the cost of throwing out
          # any other unpersisted chagnes you have. So it raises in that position -- perhaps you
          # want to write your own strategy with a custom merge method?
          module ActiveRecordOptimisticLock
            #s TBD
            # def self.call(original_attacher:, derivatives_attacher:, merge_values:)
            # end
          end
        end
      end
    end
    register_plugin(:derivatives, Derivatives)
  end
end
