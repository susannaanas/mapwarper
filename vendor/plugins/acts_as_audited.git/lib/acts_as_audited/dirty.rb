module CollectiveIdea #:nodoc
  module Acts #:nodoc
    module Audited
      # Dirty tracking module taken from edge rails:
      # http://dev.rubyonrails.org/changeset/9127
      #
      # Track unsaved attribute changes.
      #
      # A newly instantiated object is unchanged:
      #   person = Person.find_by_name('uncle bob')
      #   person.changed?       # => false
      #
      # Change the name:
      #   person.name = 'Bob'
      #   person.changed?       # => true
      #   person.name_changed?  # => true
      #   person.name_was       # => 'uncle bob'
      #   person.name_change    # => ['uncle bob', 'Bob']
      #   person.name = 'Bill'
      #   person.name_change    # => ['uncle bob', 'Bill']
      #
      # Save the changes:
      #   person.save
      #   person.changed?       # => false
      #   person.name_changed?  # => false
      #
      # Assigning the same value leaves the attribute unchanged:
      #   person.name = 'Bill'
      #   person.name_changed?  # => false
      #   person.name_change    # => nil
      #
      # Which attributes have changed?
      #   person.name = 'bob'
      #   person.changed        # => ['name']
      #   person.changes        # => { 'name' => ['Bill', 'bob'] }
      #
      # Before modifying an attribute in-place:
      #   person.name_will_change!
      #   person.name << 'by'
      #   person.name_change    # => ['uncle bob', 'uncle bobby']
      module Dirty
        def self.included(base)
          base.attribute_method_suffix '_changed?', '_change', '_will_change!', '_was'
          base.alias_method_chain :write_attribute, :dirty
          base.alias_method_chain :save,            :dirty
          base.alias_method_chain :save!,           :dirty
          # base.alias_method_chain :update,          :dirty
        end

        # Do any attributes have unsaved changes?
        #   person.changed? # => false
        #   person.name = 'bob'
        #   person.changed? # => true
        def changed?
          !changed_attributes.empty?
        end

        # List of attributes with unsaved changes.
        #   person.changed # => []
        #   person.name = 'bob'
        #   person.changed # => ['name']
        def changed
          changed_attributes.keys
        end

        # Map of changed attrs => [original value, new value]
        #   person.changes # => {}
        #   person.name = 'bob'
        #   person.changes # => { 'name' => ['bill', 'bob'] }
        def changes
          changed.inject({}) { |h, attr| h[attr] = attribute_change(attr); h }
        end


        # Clear changed attributes after they are saved.
        def save_with_dirty(*args) #:nodoc:
          save_without_dirty(*args)
        ensure
          changed_attributes.clear
        end

        # Clear changed attributes after they are saved.
        def save_with_dirty!(*args) #:nodoc:
          save_without_dirty!(*args)
        ensure
          changed_attributes.clear
        end

      private
        # Map of change attr => original value.
        def changed_attributes
          @changed_attributes ||= {}
        end

        # Handle *_changed? for method_missing.
        def attribute_changed?(attr)
          changed_attributes.include?(attr)
        end

        # Handle *_change for method_missing.
        def attribute_change(attr)
          [changed_attributes[attr], __send__(attr)] if attribute_changed?(attr)
        end

        # Handle *_was for method_missing.
        def attribute_was(attr)
          attribute_changed?(attr) ? changed_attributes[attr] : __send__(attr)
        end

        # Handle *_will_change! for method_missing.
        def attribute_will_change!(attr)
          changed_attributes[attr] = clone_attribute_value(:read_attribute, attr)
        end

        # Wrap write_attribute to remember original attribute value.
        def write_attribute_with_dirty(attr, value)
          attr = attr.to_s

          # The attribute already has an unsaved change.
          unless changed_attributes.include?(attr)
            old = clone_attribute_value(:read_attribute, attr)

            # Remember the original value if it's different.
            typecasted = if column = column_for_attribute(attr)
                           column.type_cast(value)
                         else
                           value
                         end
            changed_attributes[attr] = old unless old == typecasted
          end

          # Carry on.
          write_attribute_without_dirty(attr, value)
        end

        # def update_with_dirty
        #   update_without_dirty(changed)
        # end
      end
    end
  end
end
