# frozen_string_literal: true

"LODoc"

# Ease lazy attribute implementation to the owner class.
#
# = Usage
#
#   class Klass
#     AttrMagic.load(self)
#   end
#
# = Features
#
# == Implement a lazy attribute reader
#
#   class Person
#     …
#     attr_writer :full_name
#
#     def full_name
#       igetset(__method__) { [first_name, last_name].compact.join(" ").strip }
#     end
#   end
#
# See {InstanceMethods#igetset}, {InstanceMethods#igetwrite}.
#
# == Validate an attribute
#
#   class Person
#     …
#     def full_name
#       igetset(__method__) do
#         #require_attr :first_name                 # Will check for `nil` only.
#         require_attr :first_name, :present?
#         #require_attr :first_name, :not_blank?    # Also possible.
#         [first_name, last_name].compact.join(" ").strip
#       end
#     end
#   end
#
# See {InstanceMethods#require_attr}.
module AttrMagic
  # Load the feature into +owner+.
  # @param owner [Class]
  def self.load(owner)
    return if owner < InstanceMethods
    owner.send(:include, InstanceMethods)
    owner.class_eval { private :igetset, :igetwrite, :require_attr }
  end
end

# Load all.
Dir[File.expand_path("attr_magic/**/*.rb", __dir__)].each { |fn| require fn }
