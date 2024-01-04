# frozen_string_literal: true

module AttrMagic
  module InstanceMethods
    # Memoize a lazy attribute, given its computation block.
    #
    #   def full_name
    #     igetset(__method__) { [first_name, last_name].compact.join(" ").strip }
    #   end
    #
    # @param [Symbol | String] name
    # @return [mixed] The result of +compute+.
    # @see #igetwrite
    def igetset(name, &compute)
      if instance_variable_defined?(k = "@#{name}")
        instance_variable_get(k)
      else
        raise ArgumentError, "Code block must be given" unless compute
        instance_variable_set(k, compute.call)
      end
    end

    # Same as {#igetset}, but this one calls an attribute writer to store the computed
    # value into the object.
    # @param [Symbol | String] name
    # @return [mixed] The result of +compute+.
    # @see #igetset
    def igetwrite(name, &compute)
      if instance_variable_defined?(k = "@#{name}")
        instance_variable_get(k)
      else
        raise ArgumentError, "Code block must be given" unless compute
        send("#{name}=", compute.call)
      end
    end

    # Require an attribute to be set, present, valid or not invalid.
    #
    #   require_attr(:name)                 # Require not to be `.nil?`.
    #   require_attr(:obj, :valid)          # Require to be `.valid`.
    #   require_attr(:items, :present?)     # Require to be `.present?`.
    #   require_attr(:items, :not_empty?)   # Require not to be `.empty?`.
    #
    # @param name [Symbol | String]
    # @param predicate [Symbol | String]
    # @return [mixed] Attribute value.
    # @raise [RuntimeError]
    def require_attr(name, predicate = :not_nil?)
      # Declare in the scope.
      m = nil

      # `check` is a function returning `true` if the value is good.
      m, verb, check = if ((sp = predicate.to_s).start_with? "not_")
        [
          sp[4..-1],
          "must not",
          -> (v) { !v.public_send(m) },
        ]
      else
        [
          sp,
          "must",
          -> (v) { v.public_send(m) },
        ]
      end

      raise ArgumentError, "Invalid predicate: #{predicate.inspect}" if m.empty?

      # NOTE: Shorten the error backtrace to the minimum.

      # Get and check the value.
      v = send(name)
      check.(v) or raise "Attribute `#{name}` #{verb} be #{m.chomp('?')}: #{v.inspect}"

      v
    end
  end # InstanceMethods
end
